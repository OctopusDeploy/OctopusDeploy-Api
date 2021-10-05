import json
import requests
import base64

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

certificate_name = 'My Certificate'
certificate_notes = 'My certificate created using python via the REST API'
certificate_file_path = '/path/to/pfx_file.pfx'
certificate_file_password = 'pfx-file-password'

# Optional tenanted parameters
# Use 'Untenanted' for certificate_tenanted_deployment if multi-tenancy not required.
certificate_environments = ['Development']
certificate_tenants = ['Tenant A']
certificate_tenant_tags = ['Upgrade Ring/Stable']
certificate_tenanted_deployment = 'Tenanted'

certificate_data = open(certificate_file_path, 'rb').read()
certificate_base64 = base64.b64encode(certificate_data)

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)

environments = get_octopus_resource('{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))
environment_ids = [environment['Id'] for environment in environments if environment['Name'] in certificate_environments]

tenants = get_octopus_resource('{0}/{1}/tenants/all'.format(octopus_server_uri, space['Id']))
tenant_ids = [tenant['Id'] for tenant in tenants if tenant['Name'] in certificate_tenants]

certificate = {
    'Name': certificate_name,
    'Notes': certificate_notes,
    'certificateData': {
        'HasValue': True,
        'NewValue': certificate_base64
    },
    'Password': {
        'HasValue': True,
        'NewValue': certificate_file_password
    },
    'EnvironmentIds': environment_ids,
    'TenantIds': tenant_ids,
    'TenantTags': certificate_tenant_tags,
    'TenantedDeploymentParticipation': certificate_tenanted_deployment
}
uri = '{0}/{1}/certificates'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=certificate)
response.raise_for_status()