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
octopus_server_uri = 'https://YourURL/api'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
project_name = "MyProject"
environment_name_list = ['Environment', 'List']
tenant_tag = 'TENANT TAG TO FILTER ON'  #Format = [Tenant Tag Set Name]/[Tenant Tag] "Tenant Type/Customer"
max_number_tenants = 1
tenants_updated = 0
space_name = 'Default'
what_if = False

# Get space
uri = '{0}/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get project
uri = '{0}/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)
project = next((x for x in projects if x['Name'] == project_name), None)

# Get environments
environments = []
uri = '{0}/{1}/environments'.format(octopus_server_uri, space['Id'])
all_environments = get_octopus_resource(uri, headers)
for environment_name in environment_name_list:
    environment = next((x for x in all_environments if x['Name'] == environment_name), None)
    environments.append(environment['Id'])

# Get tenants by tag
uri = '{0}/{1}/tenants?tags={2}'.format(octopus_server_uri, space['Id'], tenant_tag)
tenants = get_octopus_resource(uri, headers)

# Loop through tenants
for tenant in tenants:
    tenant_updated = False

    if tenant['ProjectEnvironments'] == None or len(tenant['ProjectEnvironments']) == 0:
        projectEnvironments = {
            project['Id']: environments
        }

        # Attach to tenant
        tenant['ProjectEnvironments'] = projectEnvironments
        tenant_updated = True
    else:
        # Get current project environments
        projectEnvironments = tenant['ProjectEnvironments']

        # Loop through environments
        for environment in environments:
            #print (projectEnvironments[project['Id']])
            if environment not in projectEnvironments[project['Id']]:
                projectEnvironments[project['Id']].append(environment)
        
        tenant['ProjectEnvironments'] = projectEnvironments
        tenant_updated = True
    
    if tenant_updated:
        if what_if:
            print(tenant)
        else:
            uri = '{0}/{1}/tenants/{2}'.format(octopus_server_uri, space['Id'], tenant['Id'])
            response = requests.put(uri, headers=headers, json=tenant)
            response.raise_for_status
        
        tenants_updated = tenants_updated + 1
    
    if tenants_updated == max_number_tenants:
        break