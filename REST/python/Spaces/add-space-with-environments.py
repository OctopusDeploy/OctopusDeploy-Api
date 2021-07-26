import json
import requests

# Define Octopus server variables
octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

# Define working variables
space_name = "My New Space"
space_description = "Description of My New Space"
managers_teams = [] # Either this or manager_team_members must be populated otherwise you'll receive a 400
manager_team_members = [] # Either this or managers_teams must be populated otherwise you'll receive a 400
environments = ['Development', 'Test', 'Production']

# Define space JSON
space = {
    'Name' : space_name,
    'Description' : space_description,
    'SpaceManagersTeams' : managers_teams,
    'SpaceManagersTeamMembers' : manager_team_members,
    'IsDefault' : False,
    'TaskQueueStopped' : False
}

# Create the space
uri = '{0}/spaces'.format(octopus_server_uri)
response = requests.post(uri, headers=headers, json=space)
response.raise_for_status()

# Get the response object
octopus_space = json.loads(response.content.decode('utf-8'))

# Loop through environments
for environment in environments:
    environmentJson = {
        'Name': environment
    }

    # Format the uri
    uri = '{0}/{1}/environments'.format(octopus_server_uri, octopus_space['Id'])

    # Create the environment
    response = requests.post(uri, headers=headers, json=environmentJson)
    response.raise_for_status()