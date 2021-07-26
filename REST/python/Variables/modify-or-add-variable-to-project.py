import json
import requests
from requests.api import get, head

def get_octopus_resource(uri, headers, skip_count = 0):
    items = []
    response = requests.get((uri + "?skip=" + str(skip_count)), headers=headers)
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
space_name = "Default"
variable = {
    'Name': 'MyVariable',
    'Value': 'MyValue',
    'Type': 'String',
    'IsSensitive': False
}

uri = '{0}/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

uri = '{0}/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)
project = next((x for x in projects if x['Name'] == project_name), None)

if project != None:
    uri = '{0}/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], project['VariableSetId'])
    projectVariables = get_octopus_resource(uri, headers)
    projectVariable = next((x for x in projectVariables['Variables'] if x['Name'] == variable['Name']), None)

    if projectVariable == None:
        projectVariables['Variables'].append(variable)
    else:
        projectVariable['Value'] = variable['Value']
        projectVariable['Type'] = variable['Type']
        projectVariable['IsSensitive'] = variable ['IsSensitive']
   
    response = requests.put(uri, headers=headers, json=projectVariables)
    response.raise_for_status