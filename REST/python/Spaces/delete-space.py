import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = "Your Space name"

def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))

def get_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources if x['Name'] == name), None)

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
space['TaskQueueStopped'] = True

# update task queue to stopped
uri = '{0}/spaces/{1}'.format(octopus_server_uri, space['Id'])
response = requests.put(uri, headers=headers, json=space)
response.raise_for_status()

# Delete space
response = requests.delete(uri, headers=headers)
response.raise_for_status()