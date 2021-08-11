import json
import requests
import csv

octopus_server_uri = 'https://YourURL'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}

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

# Specify the Space to search in
space_name = 'Default'

# Specify the Variable to find, without OctoStache syntax 
# e.g. For #{MyProject.Variable} -> use MyProject.Variable
variable_value = 'MyValue'

csv_export_path = 'path:\\to\\variable.csv'
# Optional: set a path to export to csv

variable_tracker = []

uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)
print('Looking for usages of variable named \'{0}\' in space \'{1}\''.format(variable_value, space_name))

uri = '{0}/api/{1}/projects'.format(octopus_server_uri, space['Id'])
projects = get_octopus_resource(uri, headers)

for project in projects:
    project_name = project['Name']
    project_web_uri = project['Links']['Web'].lstrip('/')
    print('Checking project \'{0}\''.format(project_name))
    uri = '{0}/api/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], project['VariableSetId'])
    project_variable_set = get_octopus_resource(uri, headers)
    
    # Check to see if variable is named in project variables.
    matching_value_variables = [variable for variable in project_variable_set['Variables'] if variable['Value'] != None and variable_value in variable['Value']]
    if matching_value_variables is not None:
        for variable in matching_value_variables:
            tracked_variable = {
                'Project': project_name,
                'MatchType': 'Named Project Variable',
                'Context': variable['Name'],
                'AdditionalContext': None,
                'Property': None,
                'VariableSet': None
            }
            if tracked_variable not in variable_tracker:
                variable_tracker.append(tracked_variable)
    
# Get variable sets
uri = '{0}/api/{1}/libraryvariablesets?contentType=Variables'.format(octopus_server_uri, space['Id'])
variable_sets = get_octopus_resource(uri, headers)

for variable_set in variable_sets:
    uri = '{0}/api/{1}/variables/{2}'.format(octopus_server_uri, space['Id'], variable_set['VariableSetId'])
    variables = get_octopus_resource(uri, headers)
    matching_value_variables = [variable for variable in variables['Variables'] if variable['Value'] != None and variable_value in variable['Value']]
    if matching_value_variables is not None:
        for variable in matching_value_variables:
            tracked_variable = {
                'Project': None,
                'VariableSet': variable_set['Name'],
                'MatchType': 'Value in Library Set',
                'Context': variable['Value'],
                'Property': None,
                'AdditionalContext': variable['Name']
            }

            if tracked_variable not in variable_tracker:
                variable_tracker.append(tracked_variable)


results_count = len(variable_tracker)
if results_count > 0:
    print('')    
    print('Found {0} results:'.format(results_count))
    for tracked_variable in variable_tracker:
        print('Project           : {0}'.format(tracked_variable['Project']))
        print('MatchType         : {0}'.format(tracked_variable['MatchType']))
        print('Context           : {0}'.format(tracked_variable['Context']))
        print('AdditionalContext : {0}'.format(tracked_variable['AdditionalContext']))
        print('Property          : {0}'.format(tracked_variable['Property']))
        print('VariableSet              : {0}'.format(tracked_variable['VariableSet']))
        print('')
    if csv_export_path:
        with open(csv_export_path, mode='w') as csv_file:
            fieldnames = ['Project', 'MatchType', 'Context', 'AdditionalContext', 'Property', 'VariableSet']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
            writer.writeheader()
            for tracked_variable in variable_tracker:
                writer.writerow(tracked_variable)