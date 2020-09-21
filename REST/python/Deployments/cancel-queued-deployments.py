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
tasks = get_octopus_resource('{0}/{1}/tasks'.format(octopus_server_uri, space['Id']))
queued = [task for task in tasks['Items'] if task['State'] == 'Queued' and task['Name'] == 'Deploy' and not task['HasBeenPickedUpByProcessor']]

for task in queued:
    uri = '{0}/{1}/tasks/{2}/cancel'.format(octopus_server_uri, space['Id'], task['Id'])
    response = requests.post(uri, headers=headers)
    response.raise_for_status()