import requests
from requests_toolbelt import exceptions
from requests_toolbelt.downloadutils import stream


#url = 'http://abitrandom.net/core.snap'
url = 'https://7af8351798.site.internapcdn.net/debug/core.snap'

print('starting download...')
r = requests.get(url, stream=True)
stream.stream_response_to_file(r, path='core.snap')
print('done.')
