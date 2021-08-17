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
include_user_roles = True
include_non_active_users = False
include_active_directory_details = False
include_azure_active_directory = True
csv_export_path = "path:\\to\\users.csv"

# Get users
uri = '{0}/api/users'.format(octopus_server_uri)
users = get_octopus_resource(uri, headers)
users_list = []

# Loop through users
for user in users:
    if include_non_active_users != True and user['IsActive'] == False:
        continue

    user_details = {
        'Id': user['Id'],
        'Username': user['Username'],
        'DisplayName': user['DisplayName'],
        'IsActive': user['IsActive'],
        'IsService': user['IsService'],
        'EmailAddress': user['EmailAddress']
    }

    if include_user_roles:
        # Get users teams
        uri = '{0}/api/users/{1}/teams'.format(octopus_server_uri, user['Id'])
        user_team_names = get_octopus_resource(uri, headers)

        # Loop through teams
        for team_name in user_team_names:
            uri = '{0}/api/teams/{1}'.format(octopus_server_uri, team_name['Id'])
            team = get_octopus_resource(uri, headers)

            # Get scoped user roles
            uri = '{0}/api/teams/{1}/ScopedUserRoles'.format(octopus_server_uri, team['Id'])
            scoped_user_roles = get_octopus_resource(uri, headers)

            user_details['ScopedUserRoles'] = ''
            
            # Loop through roles
            for role in scoped_user_roles:
                if role['SpaceId'] == None:
                    role['SpaceId'] = 'Spaces-1'
                uri = '{0}/api/spaces/{1}'.format(octopus_server_uri, role['SpaceId'])
                space = get_octopus_resource(uri, headers)
                uri = '{0}/api/userroles/{1}'.format(octopus_server_uri, role['UserRoleId'])
                user_role = get_octopus_resource(uri, headers)
                user_details['ScopedUserRoles'] += '{0} ({1})|'.format(user_role['Name'], space['Name'])

    if include_active_directory_details:
        active_directory_identity = next((x for x in user['Identities'] if x['IdentityProviderName'] == 'Active Directory'), None)
        if active_directory_identity != None:
            user_details['AD_Upn'] = active_directory_identity['Claims']['upn']['Value']
            user_details['AD_Sam'] = active_directory_identity['Claims']['sam']['Value']
            user_details['AD_Email'] = active_directory_identity['Claims']['sam']['Value']

    if include_azure_active_directory:
        azure_ad_identity = next((x for x in user['Identities'] if x['IdentityProviderName'] == 'Azure AD'), None)
        if azure_ad_identity != None:
            user_details['AAD_Dn'] = azure_ad_identity['Claims']['dn']['Value']
            user_details['AAD_Email'] = azure_ad_identity['Claims']['email']['Value']

    print(user_details)
    users_list.append(user_details)

    if csv_export_path:
        with open(csv_export_path, mode='w') as csv_file:
            fieldnames = ['Id', 'Username', 'DisplayName', 'IsActive', 'IsService', 'EmailAddress', 'ScopedUserRoles', 'AD_Upn', 'AD_Sam', 'AD_Email', 'AAD_Dn', 'AAD_Email']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for user in users_list:
                writer.writerow(user)