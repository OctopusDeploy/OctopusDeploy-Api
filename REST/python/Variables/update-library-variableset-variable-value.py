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

octopus_server_uri = 'https://YourURL'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"
library_variable_set_name = "MyLibraryVariableSet"
variable_name = "MyVariable"
variable_value = "MyValue"

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

print('Looking for library variable set "{0}"'.format(library_variable_set_name))

# Get library variable set
uri = '{0}/api/{1}/libraryvariablesets'.format(octopus_server_uri, space['Id'])
library_variable_sets = get_octopus_resource(uri, headers)
library_variable_set = next((l for l in library_variable_sets if l['Name'] == library_variable_set_name), None)

# Check to see if something was returned
if library_variable_set == None:
    print('Library variable set not found with name "{0}"'.format(library_variable_set_name))
    exit

# Get the the variables
uri = '{0}/api/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], library_variable_set['VariableSetId'])
library_variables = get_octopus_resource(uri, headers)

# Update the variable
for variable in library_variables['Variables']:
    if variable['Name'] == variable_name:
        variable['Value'] = variable_value
        break

response = requests.put(uri, headers=headers, json=library_variables)
response.raise_for_status()