import json
import requests
from requests.api import get, head

def get_octopus_resource(uri, headers, skip_count = 0):
    items = []
    skip_querystring = ""

    if '?' in uri:
        skip_querystring = '&skip='
    else:
        skip_querystring = '?skip='

    response = requests.get((uri + skip_querystring + str(skip_count)), headers=headers)
    response.raise_for_status()

    # Get results of API call
    results = json.loads(response.content.decode('utf-8'))

    # Store results
    if 'Items' in results.keys():
        items += results['Items']

        # Check to see if there are more results
        if (len(results['Items']) > 0) and (len(results['Items']) == results['ItemsPerPage']):
            skip_count += results['ItemsPerPage']
            items += get_octopus_resource(uri, headers, skip_count)

    else:
        return results

    
    # return results
    return items

# Define Octopus server variables
octopus_server_uri = 'https://YourURL'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = 'Default'
project_name = 'MyProject'
environment_name = 'Development'
channel_name = 'Default'
tenant_names = ['MyTenant']

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get project
uri = '{0}/api/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)
project = next((x for x in projects if x['Name'] == project_name), None)

# Get channel
uri = '{0}/api/{1}/projects/{2}/channels'.format(octopus_server_uri, space['Id'], project['Id'])
channels = get_octopus_resource(uri, headers)
channel = next((x for x in channels if x['Name'] == channel_name), None)

# Get environment
uri = '{0}/api/{1}/environments'.format(octopus_server_uri, space['Id'])
environments = get_octopus_resource(uri, headers)
environment = next((x for x in environments if x['Name'] == environment_name), None)

# Get project template
uri = '{0}/api/{1}/deploymentprocesses/deploymentprocess-{2}/template?channel={3}'.format(octopus_server_uri, space['Id'], project['Id'], channel['Id'])
template = get_octopus_resource(uri, headers)

# Get release version number
releaseVersion = ""
if None == template['NextVersionIncrement']:
    uri = uri = '{0}/api/{1}/deploymentprocesses/{2}'.format(octopus_server_uri, space['Id'], project['DeploymentProcessId'])
    deploymentProcess = get_octopus_resource(uri, headers)
    for step in deploymentProcess['Steps']:
        versionNumberFound = False
        if step['Name'] == template['VersioningPackageStepName']:
            for action in step['Actions']:
                package = action['Packages'][0]
                uri = '{0}/api/{1}/feeds/{2}/packages/versions?packageId={3}&take=1'.format(octopus_server_uri, space['Id'], package['FeedId'], package['PackageId'])
                releaseVersion = get_octopus_resource(uri, headers)[0]['Version'] # Only one result is returned so using index 0
                versionNumberFound = True
                break
        if versionNumberFound:
            break

else:
    releaseVersion = template['NextVersionIncrement']

# Create release JSON
releaseJson = {
    'ChannelId': channel['Id'],
    'ProjectId': project['Id'],
    'Version': releaseVersion,
    'SelectedPackages': []
}

# Select packages for process
for package in template['Packages']:
    uri = '{0}/api/{1}/feeds/{2}/packages/versions?packageId={3}&take=1'.format(octopus_server_uri, space['Id'], package['FeedId'], package['PackageId'])
    selectedPackage = get_octopus_resource(uri, headers)[0] # Only one result is returned so using index 0
    selectedPackageJson = {
        'ActionName': package['ActionName'],
        'PackageReferenceName': package['PackageReferenceName'],
        'Version': selectedPackage['Version']
    }
    releaseJson['SelectedPackages'].append(selectedPackageJson)

# Create release
uri = '{0}/api/{1}/releases'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=releaseJson)
response.raise_for_status()

# Get results of API call
release = json.loads(response.content.decode('utf-8'))

# Get tenants
uri = '{0}/api/{1}/tenants'.format(octopus_server_uri, space['Id'])
allTenants = get_octopus_resource(uri, headers)
tenants = []
for tenant_name in tenant_names:
    tenant = next((x for x in allTenants if x['Name'] == tenant_name), None)
    tenants.append(tenant)

for tenant in tenants:
    # Create deploymentJson
    deploymentJson = {
    'ReleaseId': release['Id'],
    'EnvironmentId': environment['Id'],
    'TenantId': tenant['Id']
    }

    # Deploy
    uri = '{0}/api/{1}/deployments'.format(octopus_server_uri, space['Id'])
    response = requests.post(uri, headers=headers, json=deploymentJson)
    response.raise_for_status()