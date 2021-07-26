rimport json
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
space_name = "MySpace"

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get all projects
uri = '{0}/api/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)

for project in projects:
    uri = '{0}{1}'.format(octopus_server_uri, project['Links']['Variables'])
    projectVariables = get_octopus_resource(uri, headers)
    variablesUpdated = False

    for variable in projectVariables['Variables']:
        if variable['IsSensitive']:
            variable['Value'] = ""
            variablesUpdated = True

    if variablesUpdated:
        print ('Clearing sensitive variables for project {0}'.format(project['Name']))
        uri = '{0}{1}'.format(octopus_server_uri, project['Links']['Variables'])
        response = requests.put(uri, headers=headers, json=projectVariables)
        response.raise_for_status

# Get all variable sets
uri = '{0}/api/{1}/libraryvariablesets'.format(octopus_server_uri, space['Id'])
variableSets = get_octopus_resource(uri, headers)

for variableSet in variableSets:
    uri = '{0}{1}'.format(octopus_server_uri, variableSet['Links']['Variables'])
    libraryVariables = get_octopus_resource(uri, headers)
    variablesUpdated = False

    for variable in libraryVariables['Variables']:
        if variable['IsSensitive']:
            variable['Value'] = ""
            variablesUpdated = True

    if variablesUpdated:
        print ('Clearing senitive variables for library set {0}'.format(variableSet['Name']))
        uri = '{0}{1}'.format(octopus_server_uri, variableSet['Links']['Variables'])
        response = requests.put(uri, headers=headers, json=libraryVariables)
        response.raise_for_status