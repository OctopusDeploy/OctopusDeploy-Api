import json
import requests
import csv

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    return json.loads(response.content.decode('utf-8'))

def get_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources if x['Name'] == name), None)

# Specify the Space to search in
space_name = 'Default'

# Specify the Variable to find, without OctoStache syntax 
# e.g. For #{MyProject.Variable} -> use MyProject.Variable
variable_name = 'MyProject.Variable'

# Search through Project's Deployment Processes?
search_deployment_processes = True

# Search through Project's Runbook Processes?
search_runbook_processes = True

# Optional: set a path to export to csv
csv_export_path = ''

variable_tracker = []
octopus_server_uri = octopus_server_uri.rstrip('/')
octopus_server_baselink_uri = octopus_server_uri.rstrip('api')

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
print('Looking for usages of variable named \'{0}\' in space \'{1}\''.format(variable_name, space_name))

projects = get_octopus_resource('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))

for project in projects:
    project_name = project['Name']
    project_web_uri = project['Links']['Web'].lstrip('/')
    print('Checking project \'{0}\''.format(project_name))
    project_variable_set = get_octopus_resource('{0}/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], project['VariableSetId']))
    
    # Check to see if variable is named in project variables.
    matching_named_variables = [variable for variable in project_variable_set['Variables'] if variable_name in variable['Name']]
    if matching_named_variables is not None:
        for variable in matching_named_variables:
            tracked_variable = {
                'Project': project_name,
                'MatchType': 'Named Project Variable',
                'Context': variable['Name'],
                'AdditionalContext': None,
                'Property': None,
                'Link': '{0}{1}/variables'.format(octopus_server_baselink_uri, project_web_uri)
            }
            if tracked_variable not in variable_tracker:
                variable_tracker.append(tracked_variable)
    
    # Check to see if variable is referenced in other project variable values.
    matching_value_variables = [variable for variable in project_variable_set['Variables'] if variable['Value'] is not None and variable_name in variable['Value']]
    if matching_value_variables is not None:
        for variable in matching_value_variables:
            tracked_variable = {
                'Project': project_name,
                'MatchType': 'Referenced Project Variable',
                'Context': variable['Name'],
                'AdditionalContext': variable['Value'],
                'Property': None,
                'Link': '{0}{1}/variables'.format(octopus_server_baselink_uri, project_web_uri)
            }
            if tracked_variable not in variable_tracker:
                variable_tracker.append(tracked_variable)
    
    # Search Deployment process if enabled
    if search_deployment_processes == True:
        deployment_process = get_octopus_resource('{0}/{1}/deploymentprocesses/{2}'.format(octopus_server_uri, space['Id'], project['DeploymentProcessId']))
        for step in deployment_process['Steps']:
            for step_key in step.keys():
                step_property_value = str(step[step_key])
                if step_property_value is not None and variable_name in step_property_value:
                    tracked_variable = {
                        'Project': project_name,
                        'MatchType': 'Step',
                        'Context': step['Name'],
                        'Property': step_key,
                        'AdditionalContext': None,
                        'Link': '{0}{1}/deployments/process/steps?actionId={2}'.format(octopus_server_baselink_uri, project_web_uri, step['Actions'][0]['Id'])
                    }
                    if tracked_variable not in variable_tracker:
                        variable_tracker.append(tracked_variable)

    # Search Runbook processes if configured
    if search_runbook_processes == True:
        runbooks_resource = get_octopus_resource('{0}/{1}/projects/{2}/runbooks?skip=0&take=5000'.format(octopus_server_uri, space['Id'], project['Id']))
        runbooks = runbooks_resource['Items']
        for runbook in runbooks:
            runbook_processes_link = runbook['Links']['RunbookProcesses']
            runbook_process = get_octopus_resource('{0}/{1}'.format(octopus_server_baselink_uri, runbook_processes_link))
            for step in runbook_process['Steps']:
                for step_key in step.keys():
                    step_property_value = str(step[step_key])
                    if step_property_value is not None and variable_name in step_property_value:
                        tracked_variable = {
                            'Project': project_name,
                            'MatchType': 'Runbook Step',
                            'Context': runbook['Name'],
                            'Property': step_key,
                            'AdditionalContext': step['Name'],
                            'Link': '{0}{1}/operations/runbooks/{2}/process/{3}/steps?actionId={4}'.format(octopus_server_baselink_uri, project_web_uri, runbook['Id'], runbook['RunbookProcessId'], step['Actions'][0]['Id'])
                        }
                        if tracked_variable not in variable_tracker:
                            variable_tracker.append(tracked_variable)               

if len(variable_tracker) > 0:
    print('')    
    print('Results:')
    for tracked_variable in variable_tracker:
        print('Project           : {0}'.format(tracked_variable['Project']))
        print('MatchType         : {0}'.format(tracked_variable['MatchType']))
        print('Context           : {0}'.format(tracked_variable['Context']))
        print('AdditionalContext : {0}'.format(tracked_variable['AdditionalContext']))
        print('Property          : {0}'.format(tracked_variable['Property']))
        print('Link              : {0}'.format(tracked_variable['Link']))
        print('')
    if csv_export_path:
        with open(csv_export_path, mode='w') as csv_file:
            fieldnames = ['Project', 'MatchType', 'Context', 'AdditionalContext', 'Property', 'Link']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for tracked_variable in variable_tracker:
                writer.writerow(tracked_variable)