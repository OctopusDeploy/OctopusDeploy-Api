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
target_name = 'your-target-name'
target_tentacle_thumbprint = 'your-tentacle-thumbprint'

# The subscription id is a random 20 character id (for example: 3hw9vtskv2cbfw7zvpje) that is used to queue messages from the server to the Polling Tentacle. 
# This should match the value in the Tentacle config file.
target_polling_subscription_identifier = 'your-target-subscription'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
environments = get_octopus_resource('{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))
environment_ids = [environment['Id'] for environment in environments if environment['Name'] in environment_names]

target = {
    'Endpoint': {
        'CommunicationStyle': 'TentacleActive',
        'Thumbprint': target_tentacle_thumbprint,
        'Uri': 'poll://{0}'.format(target_polling_subscription_identifier)
    },
    'EnvironmentIds': environment_ids,
    'Name': target_name,
    'Roles': ['your-target-role'],
    'Status': 'Unknown',
    'IsDisabled': False
}

uri = '{0}/{1}/machines'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=target)
response.raise_for_status()