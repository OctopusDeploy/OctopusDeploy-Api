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

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
projects = get_octopus_resource('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))

for project in projects:
    process = get_octopus_resource('{0}/{1}/deploymentprocesses/{2}'.format(octopus_server_uri, space['Id'], project['DeploymentProcessId']))
    steps = process.get('Steps', None)
    if steps is None or len(steps) == 0:
        print('Deleting project \'{0}\' as it has no deployment process'.format(project['Name']))
        uri = '{0}/{1}/projects/{2}'.format(octopus_server_uri, space['Id'], project['Id'])
        response = requests.delete(uri, headers=headers)
        response.raise_for_status()        
