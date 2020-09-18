import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))

def get_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources if x['Name'] == name), None)


space_name = 'Default'
target_names = ['Target A', 'Target B']

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
targets = get_octopus_resource('{0}/{1}/machines/all'.format(octopus_server_uri, space['Id']))
target_ids = [target['Id'] for target in targets if target['Name'] in target_names]

task = {
    'Name': 'Upgrade',
    'Arguments': {
        'MachineIds': target_ids
    },
    'Description': 'Upgrade machines',
    'SpaceId': space['Id']
}

uri = '{0}/{1}/tasks'.format(octopus_server_uri,
                             space['Id'])
response = requests.post(uri, headers=headers, json=task)
response.raise_for_status()