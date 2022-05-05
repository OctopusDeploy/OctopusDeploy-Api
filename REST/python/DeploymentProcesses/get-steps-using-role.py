import json
import requests
octopus_server_uri = 'https://your.octopus.app/'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()
    return json.loads(response.content.decode('utf-8'))
space_name = 'Default'
role_name = 'My target role'
spaces = get_octopus_resource('{0}/api/spaces/all'.format(octopus_server_uri))
space = next((x for x in spaces if x['Name'] == space_name), None)
projects = get_octopus_resource('{0}/api/{1}/projects/all'.format(octopus_server_uri, space['Id']))
for project in projects:
    deploymentprocess_link = project['Links']['DeploymentProcess']
    if project['IsVersionControlled'] == True:
        default_branch = project['PersistenceSettings']['DefaultBranch']
        deploymentprocess_link = deploymentprocess_link.replace('{gitRef}', default_branch)
    uri = '{0}{1}'.format(octopus_server_uri, deploymentprocess_link)
    process = get_octopus_resource(uri)
    for step in process['Steps']:
        properties = step['Properties']
        roles_key = 'Octopus.Action.TargetRoles'
        roles = properties[roles_key].split(',') if roles_key in properties else None
        if roles is None:
            continue
        if role_name in roles:
            print('Step \'{0}\' of project \'{1}\' is using role \'{2}\''.format(step['Name'], project['Name'], role_name))