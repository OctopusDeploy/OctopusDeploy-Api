import json
import requests
from requests.api import get, head
import csv

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
    if hasattr(results, 'keys') and 'Items' in results.keys():
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
space_name = 'Default'
project_name = "MyProject"
team_name = "MyTeam"

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get project
uri = '{0}/api/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)
project = next((p for p in projects if p['Name'] == project_name), None)

# Get team
uri = '{0}/api/{1}/teams'.format(octopus_server_uri, space['Id'])
teams = get_octopus_resource(uri, headers)
team = next((t for t in teams if t['Name'] == team_name), None)

# Get scoped user roles
uri = '{0}/api/{1}/teams/{2}/scopeduserroles'.format(octopus_server_uri, space['Id'], team['Id'])
scoped_user_roles = get_octopus_resource(uri, headers)

for scoped_user_role in scoped_user_roles:
    if project['Id'] in scoped_user_role['ProjectIds']:
        scoped_user_role['ProjectIds'].remove(project['Id'])

        # Update the scoped user role
        print('Removing team {0} from project {1}'.format(team['Name'], project['Name']))
        uri = '{0}/api/{1}/scopeduserroles/{2}'.format(octopus_server_uri, space['Id'], scoped_user_role['Id'])
        response = requests.put(uri, headers=headers, json=scoped_user_role)
        response.raise_for_status()