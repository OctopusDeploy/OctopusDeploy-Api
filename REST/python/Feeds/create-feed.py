import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = 'Default'

feed = {
    'Id': None,
    'Name': 'nuget.org',
    'FeedUri': 'https://api.nuget.org/v3/index.json',
    'FeedType': 'NuGet',
    'DownloadAttempts': 5,
    'DownloadRetryBackoffSeconds': 10,
    'EnhancedMode': False
    # 'Username': 'uncomment to provide credentials'
    # 'Password': 'uncomment to provide credentials'
}

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

uri = '{0}/{1}/feeds'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=feed)
response.raise_for_status()