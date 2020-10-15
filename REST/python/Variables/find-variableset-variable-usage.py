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

# Specify the name of the Library VariableSet to use to find variables usage of
library_variableset_name = 'My-Variable-Set'

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
library_variableset_resource = get_by_name('{0}/{1}/libraryvariablesets/all'.format(octopus_server_uri, space['Id']), library_variableset_name)
library_variableset = get_octopus_resource('{0}/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], library_variableset_resource['VariableSetId']))
library_variableset_variables = library_variableset['Variables']
print('Looking for usages of variables from variable set \'{0}\' in space \'{1}\''.format(library_variableset_name, space_name))

projects = get_octopus_resource('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))

for project in projects:
    project_name = project['Name']
    project_web_uri = project['Links']['Web'].lstrip('/')
    print('Checking project \'{0}\''.format(project_name))
    project_variable_set = get_octopus_resource('{0}/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], project['VariableSetId']))
        
    # Check to see if there are any project variable values that reference any of the library set variables.
    for library_variableset_variable in library_variableset_variables:

        matching_value_variables = [project_variable for project_variable in project_variable_set['Variables'] if project_variable['Value'] is not None and library_variableset_variable['Name'] in project_variable['Value']]
        if matching_value_variables is not None:
            for matching_variable in matching_value_variables:
                tracked_variable = {
                    'Project': project_name,
                    'MatchType': 'Referenced Project Variable',
                    'VariableSetVariable': library_variableset_variable['Name'],
                    'Context': matching_variable['Name'],
                    'AdditionalContext': matching_variable['Value'],
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
                # Check to see if any of the variableset variables are referenced in this step's properties
                for library_variableset_variable in library_variableset_variables:
                    if step_property_value is not None and library_variableset_variable['Name'] in step_property_value:
                        tracked_variable = {
                            'Project': project_name,
                            'MatchType': 'Step',
                            'VariableSetVariable': library_variableset_variable['Name'],
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
                    # Check to see if any of the variableset variables are referenced in this step's properties
                    for library_variableset_variable in library_variableset_variables:
                        if step_property_value is not None and library_variableset_variable['Name'] in step_property_value:
                            tracked_variable = {
                                'Project': project_name,
                                'MatchType': 'Runbook Step',
                                'VariableSetVariable': library_variableset_variable['Name'],
                                'Context': runbook['Name'],
                                'Property': step_key,
                                'AdditionalContext': step['Name'],
                                'Link': '{0}{1}/operations/runbooks/{2}/process/{3}/steps?actionId={4}'.format(octopus_server_baselink_uri, project_web_uri, runbook['Id'], runbook['RunbookProcessId'], step['Actions'][0]['Id'])
                            }
                            if tracked_variable not in variable_tracker:
                                variable_tracker.append(tracked_variable)               

results_count = len(variable_tracker)
if results_count > 0:
    print('')    
    print('Found {0} results:'.format(results_count))
    for tracked_variable in variable_tracker:
        print('Project             : {0}'.format(tracked_variable['Project']))
        print('MatchType           : {0}'.format(tracked_variable['MatchType']))
        print('VariableSetVariable : {0}'.format(tracked_variable['VariableSetVariable']))
        print('Context             : {0}'.format(tracked_variable['Context']))
        print('AdditionalContext   : {0}'.format(tracked_variable['AdditionalContext']))
        print('Property            : {0}'.format(tracked_variable['Property']))
        print('Link                : {0}'.format(tracked_variable['Link']))
        print('')
    if csv_export_path:
        with open(csv_export_path, mode='w') as csv_file:
            fieldnames = ['Project', 'MatchType', 'VariableSetVariable', 'Context', 'AdditionalContext', 'Property', 'Link']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for tracked_variable in variable_tracker:
                writer.writerow(tracked_variable)