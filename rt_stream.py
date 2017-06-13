import requests
from requests_toolbelt import exceptions
from requests_toolbelt.downloadutils import stream

def download(url, path):
    print('starting download: {}'.format(url))
    r = requests.get(url, stream=True)
    stream.stream_response_to_file(r, path=path)
    print('done.')

#urls = 'http://abitrandom.net/core.snap'
urls = [
    'https://7af8351798.site.internapcdn.net/debug/core.snap',
    'https://068ed04f23.site.internapcdn.net/download-snap/99T7MUlRhtI3U0QFgl5mXXESAiSwt776_1689.snap?t=2017-06-13T21:07:40Z&h=95a401792c580e56ab11b61312879fe3b2243296'
    ]

i = 0
for url in urls:
    download(url, 'core{}.snap'.format(i))
    i+=1
  
