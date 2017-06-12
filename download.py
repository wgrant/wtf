
# -*- Mode:Python; indent-tabs-mode:nil; tab-width:4 -*-
#
# Copyright (C) 2016-2017 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import hashlib
import itertools
import logging
import os
import urllib.parse
from time import sleep
from threading import Thread
from queue import Queue

from progressbar import (
    AnimatedMarker,
    ProgressBar,
    UnknownLength,
)

import requests
from requests.adapters import HTTPAdapter
from requests.exceptions import RetryError
from requests.packages.urllib3.util.retry import Retry

import constants
from indicators import download_requests_stream

logging.basicConfig()
logging.getLogger("requests.packages.urllib3").setLevel(logging.DEBUG)
logging.getLogger("requests").setLevel(logging.DEBUG)
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

    

class Client():
    """A base class to define clients for the ols servers.

    This is a simple wrapper around requests.Session so we inherit all good
    bits while providing a simple point for tests to override when needed.

    """

    def __init__(self, conf, root_url):
        self.conf = conf
        self.root_url = root_url
        self.session = requests.Session()
        # Setup max retries for all store URLs and the CDN
        retries = Retry(total=int(os.environ.get('STORE_RETRIES', 5)),
                        backoff_factor=int(os.environ.get('STORE_BACKOFF', 2)),
                        status_forcelist=[104, 500, 502, 503, 504])
        self.session.mount('http://', HTTPAdapter(max_retries=retries))
        self.session.mount('https://', HTTPAdapter(max_retries=retries))

        self._snapcraft_headers = {
            'User-Agent': 'noise-test'
        }

    def request(self, method, url, params=None, headers=None, **kwargs):
        """Overriding base class to handle the root url."""
        # Note that url may be absolute in which case 'root_url' is ignored by
        # urljoin.

        if headers:
            headers.update(self._snapcraft_headers)
        else:
            headers = self._snapcraft_headers

        final_url = urllib.parse.urljoin(self.root_url, url)
        try:
            response = self.session.request(
                method, final_url, headers=headers,
                params=params, **kwargs)
        except RetryError as e:
            raise e
        return response

    def get(self, url, **kwargs):
        return self.request('GET', url, **kwargs)

    def post(self, url, **kwargs):
        return self.request('POST', url, **kwargs)

    def put(self, url, **kwargs):
        return self.request('PUT', url, **kwargs)


class StoreClient():
    """High-level client for the V2.0 API SCA resources."""

    def __init__(self):
        super().__init__()
        #self.conf = config.Config()
        self.conf = None
        #self.sso = SSOClient(self.conf)
        self.cpi = SnapIndexClient(self.conf)
        self.updown = UpDownClient(self.conf)
        #self.sca = SCAClient(self.conf)

    def get_snap_revisions(self, snap_name, series=None, arch=None):
        if series is None:
            series = constants.DEFAULT_SERIES

        account_info = self.get_account_information()
        try:
            snap_id = account_info['snaps'][series][snap_name]['snap-id']
        except KeyError as e:
            raise e

        response = self._refresh_if_necessary(
            self.sca.snap_revisions, snap_id, series, arch)

        if not response:
            raise

        return response

    def get_snap_status(self, snap_name, series=None, arch=None):
        if series is None:
            series = constants.DEFAULT_SERIES

        account_info = self.get_account_information()
        try:
            snap_id = account_info['snaps'][series][snap_name]['snap-id']
        except KeyError:
            raise

        response = self._refresh_if_necessary(
            self.sca.snap_status, snap_id, series, arch)

        if not response:
            raise

        return response

    def download(self, snap_name, channel, download_path,
                 arch=None, except_hash=''):
        if arch is None:
            arch = 'amd64'

        package = self.cpi.get_package(snap_name, channel, arch)
        if package['download_sha3_384'] != except_hash:
            self._download_snap(
                snap_name, channel, arch, download_path,
                # FIXME LP: #1662665
                package['anon_download_url'], package['download_sha512'])
        return package['download_sha3_384']

    def _download_snap(self, name, channel, arch, download_path,
                       download_url, expected_sha512):
        if self._is_downloaded(download_path, expected_sha512):
            logger.info('Already downloaded {} at {}'.format(
                name, download_path))
            return
        logger.info('Downloading {}'.format(name, download_path))

        # we only resume when redirected to our CDN since we use internap's
        # special sauce.
        resume_possible = False
        total_read = 0
        probe_url = requests.head(download_url)
        if (probe_url.is_redirect and
                'internap' in probe_url.headers['Location']):
            download_url = probe_url.headers['Location']
            resume_possible = True

        # HttpAdapter cannot help here as this is a stream.
        # LP: #1617765
        not_downloaded = True
        retry_count = 5
        while not_downloaded and retry_count:
            headers = {}
            if resume_possible and os.path.exists(download_path):
                total_read = os.path.getsize(download_path)
                headers['Range'] = 'bytes={}-'.format(total_read)
            # hack a diff url
            download_url = 'https://abitrandom.net/core.snap'
            request = self.cpi.get(download_url, headers=headers, stream=True)
            request.raise_for_status()
            redirections = [h.headers['Location'] for h in request.history]
            if redirections:
                logger.debug('Redirections for {!r}: {}'.format(
                    download_url, ', '.join(redirections)))
            try:
                download_requests_stream(request, download_path,
                                         total_read=total_read)
                not_downloaded = False
            except requests.exceptions.ChunkedEncodingError as e:
                logger.debug('Error while downloading: {!r}. '
                             'Retries left to download: {!r}.'.format(
                                 e, retry_count))
                logger.debug('Response Headers: {!r}'.format(request.headers))
                retry_count -= 1
                if not retry_count:
                    raise e
                sleep(1)

        if self._is_downloaded(download_path, expected_sha512):
            logger.info('Successfully downloaded {} at {}'.format(
                name, download_path))
        else:
            raise 'sha mismatch'

    def _is_downloaded(self, path, expected_sha512):
        if not os.path.exists(path):
            return False

        file_sum = hashlib.sha512()
        with open(path, 'rb') as f:
            for file_chunk in iter(
                    lambda: f.read(file_sum.block_size * 128), b''):
                file_sum.update(file_chunk)
        return expected_sha512 == file_sum.hexdigest()


class SnapIndexClient(Client):
    """The Click Package Index knows everything about existing snaps.

    https://wiki.ubuntu.com/AppStore/Interfaces/ClickPackageIndex is the
    canonical reference.
    """

    def __init__(self, conf):
        super().__init__(conf, os.environ.get(
            'UBUNTU_STORE_SEARCH_ROOT_URL',
            constants.UBUNTU_STORE_SEARCH_ROOT_URL))

    def get_default_headers(self):
        """Return default headers for CPI requests.

        Tries to build an 'Authorization' header with local credentials
        if they are available.
        Also pin specific branded store if `SNAPCRAFT_UBUNTU_STORE`
        environment is set.
        """
        headers = {}

        branded_store = os.getenv('SNAPCRAFT_UBUNTU_STORE')
        if branded_store:
            headers['X-Ubuntu-Store'] = branded_store

        return headers

    def get_package(self, snap_name, channel, arch=None):
        headers = self.get_default_headers()
        headers.update({
            'Accept': 'application/hal+json',
            'X-Ubuntu-Release': constants.DEFAULT_SERIES,
        })
        if arch:
            headers['X-Ubuntu-Architecture'] = arch

        params = {
            'channel': channel,
            # FIXME LP: #1662665
            'fields': 'status,anon_download_url,download_url,'
                      'download_sha3_384,download_sha512,snap_id,'
                      'revision,release',
        }
        logger.debug('Getting details for {}'.format(snap_name))
        url = 'api/v1/snaps/details/{}'.format(snap_name)
        resp = self.get(url, headers=headers, params=params)
        if resp.status_code != 200:
            raise Exception('non 200 response: %s', resp.status_code)
        return resp.json()

    def get(self, url, headers=None, params=None, stream=False):
        if headers is None:
            headers = self.get_default_headers()
        response = self.request('GET', url, stream=stream,
                                headers=headers, params=params)
        return response


class UpDownClient(Client):
    """The Up/Down server provide upload/download snap capabilities."""

    def __init__(self, conf):
        super().__init__(conf, os.environ.get(
            'UBUNTU_STORE_UPLOAD_ROOT_URL',
            constants.UBUNTU_STORE_UPLOAD_ROOT_URL))

    def upload(self, monitor):
        return self.post(
            urllib.parse.urljoin(self.root_url, 'unscanned-upload/'),
            data=monitor, headers={'Content-Type': monitor.content_type,
                                   'Accept': 'application/json'})


class StatusTracker:

    __messages = {
        'being_processed': 'Processing...',
        'ready_to_release': 'Ready to release!',
        'need_manual_review': 'Will need manual review...',
        'processing_upload_delta_error': 'Error while processing delta...',
        'processing_error': 'Error while processing...',
    }

    __error_codes = {
        'processing_error',
        'processing_upload_delta_error',
        'need_manual_review',
    }

    def __init__(self, status_details_url):
        self.__status_details_url = status_details_url

    def track(self):
        queue = Queue()
        thread = Thread(target=self._update_status, args=(queue,))
        thread.start()

        widgets = ['Processing...', AnimatedMarker()]
        progress_indicator = ProgressBar(widgets=widgets, maxval=UnknownLength)
        progress_indicator.start()

        content = {}
        for indicator_count in itertools.count():
            progress_indicator.update(indicator_count)
            if not queue.empty():
                content = queue.get()
                if isinstance(content, Exception):
                    raise content
            if content.get('processed'):
                break
            else:
                widgets[0] = self._get_message(content)
            sleep(0.1)
        progress_indicator.finish()
        # Print at the end to avoid a left over spinner artifact
        print(self._get_message(content))

        self.__content = content

        return content

    def raise_for_code(self):
        if self.__content['code'] in self.__error_codes:
            raise Exception(self.__content)

    def _get_message(self, content):
        try:
            return self.__messages.get(content['code'], content['code'])
        except KeyError:
            return self.__messages.get('being_processed')

    def _update_status(self, queue):
        for content in self._get_status():
            queue.put(content)
            if content['processed']:
                break
            sleep(constants.SCAN_STATUS_POLL_DELAY)

    def _get_status(self):
        connection_errors_allowed = 10
        while True:
            try:
                content = requests.get(self.__status_details_url).json()
            except (requests.ConnectionError, requests.HTTPError) as e:
                if not connection_errors_allowed:
                    yield e
                content = {'processed': False, 'code': 'being_processed'}
                connection_errors_allowed -= 1
            yield content


if __name__ == '__main__':
    c = StoreClient()
    c.download('core', 'stable', './core.snap')

