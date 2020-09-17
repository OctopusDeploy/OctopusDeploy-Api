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
libraryset_name = 'Your variable set name'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
library_variable_set = get_by_name('{0}/{1}/libraryvariablesets/all'.format(octopus_server_uri, space['Id']), libraryset_name)
library_variable_set_id = library_variable_set['Id']

projects = get_octopus_resource('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))

for project in projects:
    project_variable_sets = project['IncludedLibraryVariableSetIds']
    if library_variable_set_id in project_variable_sets:
        print('Project \'{0}\' is using library variable set \'{1}\''.format(project['Name'], libraryset_name))