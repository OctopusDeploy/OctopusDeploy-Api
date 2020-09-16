import json
import requests
octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()
    return json.loads(response.content.decode('utf-8'))
space_name = 'Default'
package_id = 'YourPackageId'
spaces = get_octopus_resource('{0}/spaces/all'.format(octopus_server_uri))
space = next((x for x in spaces if x['Name'] == space_name), None)
projects = get_octopus_resource(
    '{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))
for project in projects:
    uri = '{0}/{1}/deploymentprocesses/{2}'.format(octopus_server_uri, space['Id'], project['DeploymentProcessId'])
    process = get_octopus_resource(uri)
    for step in process['Steps']:
        packages = [package for action in step['Actions'] for package in action['Packages']]
        if (packages is None):
            continue
        ids = [package['PackageId'] for package in packages]
        if (package_id in ids):
            print('Step \'{0}\' of project \'{1}\' is using package \'{2}\''.format(step['Name'], project['Name'], package_id))