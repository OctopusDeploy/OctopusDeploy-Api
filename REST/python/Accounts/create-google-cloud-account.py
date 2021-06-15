# Note: This script will only work with Octopus 2021.2 and higher.
import json
import requests
import base64

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = 'Default'
google_cloud_account_name = 'My Google Cloud Account'
google_cloud_account_description = 'A Google Cloud account for my project'
tenanted_participation = 'Untenanted'

tenant_tags = []
tenant_ids = []
environment_ids = []

json_keyfile_path = '/path/to/jsonkeyfile.json'
json_data = open(json_keyfile_path, 'rb').read()
json_key_base64 = base64.b64encode(json_data)

account = {
    'Id': None,
    'AccountType': 'GoogleCloudAccount',
    'JsonKey': {
        'HasValue': True,
        'NewValue': json_key_base64
    },
    'Name': google_cloud_account_name, 
    'Description': google_cloud_account_description, 
    'TenantedDeploymentParticipation': tenanted_participation,
    'TenantTags': tenant_tags,
    'TenantIds': tenant_ids,
    'EnvironmentIds': environment_ids
}
uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()
spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)
uri = '{0}/{1}/accounts'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=account)
response.raise_for_status()