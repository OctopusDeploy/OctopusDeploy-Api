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
target_name = 'Your Target Name'
target_role = 'your-product-role'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
target = get_by_name('{0}/{1}/machines/all'.format(octopus_server_uri, space['Id']), target_name)

target['Roles'].append(target_role)

uri = '{0}/{1}/machines/{2}'.format(octopus_server_uri, space['Id'], target['Id'])
response = requests.put(uri, headers=headers, json=target)
response.raise_for_status()