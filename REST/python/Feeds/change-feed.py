import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = "Default"
feed_name = 'nuget.org'
new_name = 'nuget.org updated feed'

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

uri = '{0}/{1}/feeds/all'.format(octopus_server_uri, space['Id'])
response = requests.get(uri, headers=headers)
response.raise_for_status()

feeds = json.loads(response.content.decode('utf-8'))
feed = next((x for x in feeds if x['Name'] == feed_name), None)
feed['Name'] = new_name

uri = '{0}/{1}/feeds/{2}'.format(octopus_server_uri, space['Id'], feed['Id'])
response = requests.put(uri, headers=headers, json=feed)
response.raise_for_status()