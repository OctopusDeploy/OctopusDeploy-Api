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
role_name = 'Project deployer'
space_name = 'Default'
headers = {'X-Octopus-ApiKey': octopus_api_key}

# Get users
uri = '{0}/api/users'.format(octopus_server_uri)
users = get_octopus_resource(uri, headers)

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get teams
uri = '{0}/api/teams'.format(octopus_server_uri)
teams = get_octopus_resource(uri, headers)

# Get the role in question
uri = '{0}/api/userroles'.format(octopus_server_uri)
user_roles = get_octopus_resource(uri, headers)
user_role = next((x for x in user_roles if x['Name'] == role_name), None)

# Loop through teams
for team in teams:
    # Get the scoped user roles
    uri = '{0}/api/teams/{1}/scopeduserroles'.format(octopus_server_uri, team['Id'])
    scoped_user_roles = get_octopus_resource(uri, headers)

    # Get the role that matches
    scoped_user_role = next((r for r in scoped_user_roles if r['UserRoleId'] == user_role['Id']), None)

    # Check to see if it has the role
    if scoped_user_role != None:
        print ('Team: {0}'.format(team['Name']))
        print('Users:')
        # Display the team members
        for user_id in team['MemberUserIds']:
            
            uri = '{0}/api/users/{1}'.format(octopus_server_uri, user_id)
            user = get_octopus_resource(uri, headers)

            print(user['DisplayName'])

        if team['ExternalSecurityGroups'] != None and len(team['ExternalSecurityGroups']) > 0:
            for group in team['ExternalSecurityGroups']:
                print(group['Id'])