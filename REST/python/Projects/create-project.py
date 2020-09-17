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
project_name = 'Your new Project Name'
project_description = 'My project created with python'
project_group_name = 'Default Project Group'
lifecycle_name = 'Default Lifecycle'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
project_group = get_by_name('{0}/{1}/projectgroups/all'.format(octopus_server_uri, space['Id']), project_group_name)
lifecycle = get_by_name('{0}/lifecycles/all'.format(octopus_server_uri, space['Id']), lifecycle_name)

project = {
    'Name': project_name,
    'Description': project_description,
    'ProjectGroupId': project_group['Id'],
    'LifeCycleId': lifecycle['Id']
}

uri = '{0}/{1}/projects'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=project)
response.raise_for_status()