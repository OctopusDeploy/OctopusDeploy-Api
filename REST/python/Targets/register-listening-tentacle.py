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
environment_names = ['Development', 'Test']

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
environments = get_octopus_resource('{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))
environment_ids = [environment['Id'] for environment in environments if environment['Name'] in environment_names]

params = {
    'host': 'your target hostname',
    'port': '10933',
    'type': 'TentaclePassive'
}
uri = '{0}/{1}/machines/discover'.format(octopus_server_uri, space['Id'])
response = requests.get(uri, headers=headers, params=params)
response.raise_for_status()

discovered = json.loads(response.content.decode('utf-8'))

target = {
    'Endpoint': discovered['Endpoint'],
    'EnvironmentIds': environment_ids,
    'Name': discovered['Name'],
    'Roles': ['your-target-role']
}

uri = '{0}/{1}/machines'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=target)
response.raise_for_status()