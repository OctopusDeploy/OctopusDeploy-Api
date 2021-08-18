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
source_environment_name = 'Production'
destination_environment_name = 'Test'
project_name_list = ['MyProject']

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get source environment
uri = '{0}/api/{1}/environments'.format(octopus_server_uri, space['Id'])
environments = get_octopus_resource(uri, headers)
source_environment = next((x for x in environments if x['Name'] == source_environment_name), None)
destination_environment = next((x for x in environments if x['Name'] == destination_environment_name), None)

print ('The space Id for the space name {0} is {1}'.format(space['Name'], space['Id']))
print ('The environment Id for the environment {0} is {1}'.format(source_environment['Name'], source_environment['Id']))
print ('The environment Id for the environment {0} is {1}'.format(destination_environment['Name'], destination_environment['Id']))

# Get all projects
uri = '{0}/api/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)

# Loop through projects
for project_name in project_name_list:
    # Get the project
    project = next((x for x in projects if x['Name'] == project_name), None)

    print('The project Id for project name {0} is {1}'.format(project['Name'], project['Id']))
    print('I have all the Ids I need, I am going to find the most recent successful deployment to {0}'.format(source_environment['Name']))

    uri = '{0}/api/tasks?environment={1}&project={2}&name=Deploy&states=Success&spaces={3}&includesystem=false'.format(octopus_server_uri, source_environment['Id'], project['Id'], space['Id'])
    source_task_list = get_octopus_resource(uri, headers)

    if len(source_task_list) == 0:
        print('Unable to find a successful deployment for {0} to {1}'.format(project['Name'], source_environment['Name']))
        continue

    # Get last deployment task
    last_source_deployment_task = source_task_list[0]
    last_source_deployment_id = last_source_deployment_task['Arguments']['DeploymentId']
    
    print ('The Id of the last deployment for {0} to {1} is {2}'.format(project['Name'], source_environment['Name'], last_source_deployment_id))

    # Get deployment details
    uri = '{0}/api/{1}/deployments/{2}'.format(octopus_server_uri, space['Id'], last_source_deployment_id)
    last_source_deployment = get_octopus_resource(uri, headers)
    last_source_release_id = last_source_deployment['ReleaseId']

    print ('The release Id for {0} is {1}'.format(last_source_deployment_id, last_source_release_id))

    can_promote = False

    print ('I have all the Ids I need, I am going to find the most recent successfule deployment to {0}'.format(destination_environment['Name']))

    uri = '{0}/api/tasks?environment={1}&project={2}&name=Deploy&states=Success&spaces={3}&includesystem=false'.format(octopus_server_uri, destination_environment['Id'], project['Id'], space['Id'])
    destination_task_list = get_octopus_resource(uri, headers)

    if len(destination_task_list) == 0:
        print('The destination has no releases, promoting')
        can_promote = True

    last_destination_depoloyment_task = destination_task_list[0]
    last_destination_deployment_id = last_destination_depoloyment_task['Arguments']['DeploymentId']

    print('The deployment Id of the last deployment for {0} to {1} is {2}'.format(project['Name'], destination_environment['Name'], last_destination_deployment_id))

    # Get deployment details
    uri = '{0}/api/{1}/deployments/{2}'.format(octopus_server_uri, space['Id'], last_destination_deployment_id)
    last_destination_deployment = get_octopus_resource(uri, headers)
    last_destination_release_id = last_destination_deployment['ReleaseId']

    print('The release Id for the last deployment to the destination is {0}'.format(last_destination_release_id))

    if last_destination_release_id != last_source_release_id:
        print('The releases on teh source and destination do not match, promoting')
        can_promote = True
    else:
        print('Nothing to promote for {0}'.format(project['Name']))
        continue

    # Create deployment object
    new_deployment = {
        'EnvironmentId': destination_environment['Id'],
        'ReleaseId': last_source_release_id
    }

    # Post deployment
    uri = '{0}/api/{1}/deployments'.format(octopus_server_uri, space['Id'])
    response = requests.post(uri, headers=headers, json=new_deployment)
    response.raise_for_status()