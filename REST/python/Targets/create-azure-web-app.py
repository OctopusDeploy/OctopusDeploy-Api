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
azure_account_name = 'Your Azure Account Name'
environment_names = ['Development', 'Test']
roles = ['your-product-web']

spaces = get_octopus_resource('{0}/spaces/all'.format(octopus_server_uri))
space = next((x for x in spaces if x['Name'] == space_name), None)

azure_accounts = get_octopus_resource('{0}/{1}/accounts/all'.format(octopus_server_uri, space['Id']))
azure_account = next((x for x in azure_accounts if x['Name'] == azure_account_name), None)

environments = get_octopus_resource('{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))
environment_ids = [e['Id'] for e in environments if e['Name'] in environment_names]

azure_web_app = {
    'Name': 'New Azure Web App',
    'EndPoint': {
        'CommunicationStyle': 'AzureWebApp',
        'AccountId': azure_account['Id'],
        'ResourceGroupName': 'Your Resource Group',
        'WebAppName': 'Your Web App'
    },
    'Roles': roles,
    'EnvironmentIds': environment_ids
}

uri = '{0}/{1}/machines'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=azure_web_app)
response.raise_for_status()