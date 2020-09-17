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

def get_by_role(uri, role):
    resources = get_octopus_resource(uri)
    return list(filter(lambda x: role in x['Roles'], resources))

space_name = 'Default'
target_role = 'your-target-role'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
targets = get_by_role('{0}/{1}/machines/all'.format(octopus_server_uri, space['Id']), target_role)

for target in targets:
    print('Deleting {0} ({1})'.format(target['Name'], target['Id']))
    uri = '{0}/{1}/machines/{2}'.format(octopus_server_uri, space['Id'], target['Id'])
    response = requests.delete(uri, headers=headers)
    response.raise_for_status()