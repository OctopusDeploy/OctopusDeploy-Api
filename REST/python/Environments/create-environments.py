import json
import requests
from urllib.parse import quote

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))

def post_octopus_resource(uri, body):
    response = requests.post(uri, headers=headers, json=body)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))

def get_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources['Items'] if x['Name'] == name), None)

space_name = 'Default'
environment_names = ['Development', 'Test', 'Staging', 'Production']

space = get_by_name('{0}/spaces?partialName={1}&skip=0&take=100'.format(octopus_server_uri, quote(space_name)), space_name)

for environment_name in environment_names:
    existing_environment = get_by_name('{0}/{1}/environments?partialName={2}&skip=0&take=100'.format(octopus_server_uri, space['Id'], quote(environment_name)), environment_name)
    if existing_environment is None:
        print('Creating environment \'{0}\''.format(environment_name))
        environment = {
            'Name': environment_name
        }
        environment_resource = post_octopus_resource('{0}/{1}/environments'.format(octopus_server_uri, space['Id']), environment)
        print('EnvironmentId: \'{0}\''.format(environment_resource['Id']))
    else:
        print('Environment \'{0}\' already exists. Nothing to create :)'.format(environment_name))