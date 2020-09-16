import json
import requests
octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = 'Default'
account = {
    'Id': None,
    'AccountType': 'AzureServicePrincipal',
    'AzureEnvironment': '',
    'SubscriptionNumber': 'Subscription GUID', # replace with valid GUID
    'Password': {
        'HasValue': True,
        'NewValue': 'App registration secret' # replace with valid secret
    },
    'TenantId': 'Tenant GUID', # replace with valid GUID
    'ClientId': 'Client GUID', # replace with valid GUID
    'ActiveDirectoryEndpointBaseUri': '',
    'ResourceManagementEndpointBaseUri': '',
    'Name': 'Azure Account Name', # replace with preferred name
    'Description': 'Azure Account Description', # replace with preferred description
    'TenantedDeploymentParticipation': 'Untenanted',
    'TenantTags': [],
    'TenantIds': [],
    'EnvironmentIds': []
}
uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()
spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)
uri = '{0}/{1}/accounts'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=account)
response.raise_for_status()