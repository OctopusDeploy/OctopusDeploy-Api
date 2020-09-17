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
project_name = 'Your Project Name'
runbook_name = 'Your new runbook name'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
project = get_by_name('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']), project_name)

runbook = {
    'Id': None,
    'Name': runbook_name,
    'ProjectId': project['Id'],
    'EnvironmentScope': 'All',
    'RunRetentionPolicy': {
        'QuantityToKeep': 100,
        'ShouldKeepForever': False
    }
}

uri = '{0}/{1}/runbooks'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=runbook)
response.raise_for_status()