import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}


def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))


space_name = 'Default'
project_name = 'Your Project'
step_name = 'Your Step'
environment_names = ['Development', 'Test']
environments = []

spaces = get_octopus_resource('{0}/spaces/all'.format(octopus_server_uri))
space = next((x for x in spaces if x['Name'] == space_name), None)

environments = get_octopus_resource(
    '{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))
environments = [e['Id']
                for e in environments if e['Name'] in environment_names]

projects = get_octopus_resource(
    '{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))
project = next((x for x in projects if x['Name'] == project_name), None)

uri = '{0}/{1}/deploymentprocesses/{2}'.format(
    octopus_server_uri, space['Id'], project['DeploymentProcessId'])
process = get_octopus_resource(uri)
step = next((s for s in process['Steps'] if s['Name'] == step_name), None)

for action in step['Actions']:
    new_environments = set(action['Environments'] + environments)
    action['Environments'] = list(new_environments)

response = requests.put(uri, headers=headers, json=process)
response.raise_for_status()