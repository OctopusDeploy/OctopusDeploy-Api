import json
import requests

# Define Octopus server variables
octopus_server_uri = 'https://YourUrl'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = 'Default'
team_name = 'MyTeam'
user_role_name = 'MyRole'
environment_names = ['List', 'of', 'environment names']

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

# Get space
spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get team
uri = '{0}/{1}/teams'.format(octopus_server_uri, space['Id'])
response = requests.get(uri, headers=headers)
response.raise_for_status
teams = json.loads(response.content.decode('utf-8'))
team = next((x for x in teams['Items'] if x['Name'] == team_name), None)

# Get userrole
uri = '{0}/userroles'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status
userroles = json.loads(response.content.decode('utf-8'))
userrole = next((x for x in userroles['Items'] if x['Name'] == user_role_name), None)

# Get scopeduserrole
uri = '{0}/{1}/teams/{2}/scopeduserroles'.format(octopus_server_uri, space['Id'], team['Id'])
response = requests.get(uri, headers=headers)
response.raise_for_status
scopeduserroles = json.loads(response.content.decode('utf-8'))
scopeduserrole = next((x for x in scopeduserroles['Items'] if x['UserRoleId'] == userrole['Id']), None)

# Get environments
uri = '{0}/{1}/environments'.format(octopus_server_uri, space['Id'])
response = requests.get(uri, headers=headers)
response.raise_for_status
environments = json.loads(response.content.decode('utf-8'))

# Loop through environment names
for environment_name in environment_names:
    environment = next((x for x in environments['Items'] if x['Name'] == environment_name), None)
    scopeduserrole['EnvironmentIds'].append(environment['Id'])

# Update the user role
uri = '{0}/{1}/scopeduserroles/{2}'.format(octopus_server_uri, space['Id'], scopeduserrole['Id'])
response = requests.put(uri, headers=headers, json=scopeduserrole)
response.raise_for_status