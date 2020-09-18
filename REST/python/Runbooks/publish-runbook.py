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

def get_item_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources['Items'] if x['Name'] == name), None)

space_name = 'Default'
project_name = 'Your project'
runbook_name = 'Your runbook'
snapshot_name = 'Snapshot YVVCRLF'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
project = get_by_name('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']), project_name)
runbook = get_item_by_name('{0}/{1}/projects/{2}/runbooks'.format(octopus_server_uri, space['Id'], project['Id']), runbook_name)
snapshot = get_item_by_name('{0}/{1}/projects/{2}/runbookSnapshots/'.format(octopus_server_uri, space['Id'], project['Id']), snapshot_name)

runbook['PublishedRunbookSnapshotId'] = snapshot['Id']

uri = '{0}/{1}/runbooks/{2}'.format(octopus_server_uri, space['Id'], runbook['Id'])
response = requests.put(uri, headers=headers, json=runbook)
response.raise_for_status()