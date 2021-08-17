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
csv_export_path = "path:\\to\\editpermissions.csv"

# Get users
uri = '{0}/api/users'.format(octopus_server_uri)
users = get_octopus_resource(uri, headers)
users_list = []

# Loop through users
for user in users:
    uri = '{0}/api/users/{1}/permissions'.format(octopus_server_uri, user['Id'])
    user_permissions = get_octopus_resource(uri, headers)

    edit_permission = []
    # Loop through space permissions
    for space_permission in user_permissions['SpacePermissions']:
        if "Create" in space_permission or "Delete" in space_permission or "Edit" in space_permission:
            edit_permission.append(space_permission)

    
    if len(edit_permission) > 0:
        users_list.append({
            'Id': user['Id'],
            'EmailAddress': user['EmailAddress'],
            'Username': user['Username'],
            'DisplayName': user['DisplayName'],
            'IsActive': user['IsActive'],
            'IsService': user['IsService'],
            'Permissions': '|'.join(edit_permission)
        })

    if csv_export_path:
        with open(csv_export_path, mode='w') as csv_file:
            fieldnames = ['Id', 'EmailAddress', 'Username', 'DisplayName', 'IsActive', 'IsService', 'Permissions']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for user in users_list:
                writer.writerow(user)