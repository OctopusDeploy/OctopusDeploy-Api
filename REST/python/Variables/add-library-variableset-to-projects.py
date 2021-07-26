import json
import requests
from requests.api import head

def get_octopus_resource(uri, headers, skip_count = 0):
    items = []
    response = requests.get((uri + "?skip=" + str(skip_count)), headers=headers)
    response.raise_for_status()

    # Get results of API call
    results = json.loads(response.content.decode('utf-8'))

    # Store results
    items += results['Items']

    # Check to see if there are more results
    if (len(results['Items']) > 0) and (len(results['Items']) == results['ItemsPerPage']):
        skip_count += results['ItemsPerPage']
        items += get_octopus_resource(uri, headers, skip_count)
    
    # return results
    return items


# Define Octopus server variables
octopus_server_uri = 'https://YourUrl/api'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
project_name = "MyProject"
library_set_name = "MyLibraryVariableSet"
space_name = "Default"

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

# Get space
spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get project
uri = '{0}/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)
project = next((x for x in projects if x['Name'] == project_name), None)

# Get library set
uri = '{0}/{1}/libraryvariablesets'.format(octopus_server_uri, space['Id'])
librarysets = get_octopus_resource(uri, headers)
libraryset = next((x for x in librarysets if x['Name'] == library_set_name), None)

# Check to see if project is none
if project != None:
    if libraryset != None:
        # Add set to project
        project['IncludedLibraryVariableSetIds'].append(libraryset['Id'])

        # Update project
        uri = '{0}/{1}/projects/{2}'.format(octopus_server_uri, space['Id'], project['Id'])
        response = requests.put(uri, headers=headers, json=project)
        response.raise_for_status
    else:
        print ("Library set {0} not found!".format(library_set_name))
else:
    print ("Project {0} not found!".format(project_name))