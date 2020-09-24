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
targets = get_octopus_resource('{0}/{1}/machines/all'.format(octopus_server_uri,
                                                             space['Id']))
workers = get_octopus_resource('{0}/{1}/workers/all'.format(octopus_server_uri,
                                                            space['Id']))

tentacles = [tentacle for tentacle in targets + workers
             if 'Endpoint' in tentacle and 'TentacleVersionDetails' in tentacle['Endpoint']]

for tentacle in tentacles:
    details = tentacle['Endpoint']['TentacleVersionDetails']
    print('Checking Tentacle version for {0}'.format(tentacle['Name']))
    print('\tTentacle status: {0}'.format(tentacle['HealthStatus']))
    print('\tCurrent version: {0}'.format(details['Version']))
    print('\tUpgrade suggested: {0}'.format(details['UpgradeSuggested']))
    print('\tUpgrade required: {0}'.format(details['UpgradeRequired']))