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

octopus_server_uri = 'https://your.octopusdemos.app'
octopus_api_key = 'API-YOURKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"
tenant_name = "MyTenant"
variable_template_name = "Tenant.Site.HostName"
new_value = "MyValue"
new_value_bound_to_octopus_variable = False

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get tenants
uri = '{0}/api/{1}/tenants'.format(octopus_server_uri, space['Id'])
tenants = get_octopus_resource(uri, headers)
tenant = next((t for t in tenants if t['Name'] == tenant_name), None)

# Get tenant variables
uri = '{0}/api/{1}/tenants/{2}/variables'.format(octopus_server_uri, space['Id'], tenant['Id'])
tenant_variables = get_octopus_resource(uri, headers)
variable_template = None

# Loop through connected projects
for projectKey in tenant_variables['ProjectVariables']:
    templates = tenant_variables['ProjectVariables'][projectKey]['Templates']
    
    # Loop through the project templates
    for template in templates:
        is_sensitive = (template['DisplaySettings']['Octopus.ControlType'] == 'Sensitive')
        if template['Name'] == variable_template_name:
            variable_template = template
            break
    
    if variable_template != None:
        # Loop through connected environments
        environment_variables = tenant_variables['ProjectVariables'][projectKey]['Variables']
        
        for environment_variable in environment_variables:
            variables = tenant_variables['ProjectVariables'][projectKey]['Variables'][environment_variable]
            if is_sensitive:
                new_sensitive_variable = {
                    'HasValue': True,
                    'NewValue': new_value_bound_to_octopus_variable
                }
                variables[variable_template['Id']] = new_sensitive_variable
            else:
                variables[variable_template['Id']] = new_value

# Update the tenants variables
uri = '{0}/api/{1}/tenants/{2}/variables'.format(octopus_server_uri, space['Id'], tenant['Id'])
response = requests.put(uri, headers=headers, json=tenant_variables)
response.raise_for_status()