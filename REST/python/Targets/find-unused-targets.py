import json
import requests
from requests.api import get, head
import datetime
from dateutil.parser import parse

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

def find_duplicate_entry(categorized_machines, machine):
    machineEndpoint = machine['Endpoint']
    
    for entry in categorized_machines['ListeningTentacles']:
        entryEndpoint = entry['Endpoint']
        

        if entryEndpoint['Thumbprint'] == machineEndpoint['Thumbprint'] and entryEndpoint['Uri'] == machine['Uri']:
            return entry

    
    return None


def update_categorized_machines(categorized_machines, space, octopus_server_uri, headers, unsupported_communication_styles, tentacle_communication_styles):
    # Get machines for space
    uri = '{0}/api/{1}/machines'.format(octopus_server_uri, space['Id'])
    machine_list = get_octopus_resource(uri, headers)
    current_date = datetime.datetime.utcnow()

    for machine in machine_list:
        categorized_machines['TotalMachines'] += 1

        if machine['Endpoint']['CommunicationStyle'] in unsupported_communication_styles:
            categorized_machines['NotCountedMachines'].append(machine)
            continue
        
        if machine['Endpoint']['CommunicationStyle'] in tentacle_communication_styles:
            if machine['Endpoint']['CommunicationStyle'] == "TentaclePassive":
                # Search for duplicate
                duplicate_machine = find_duplicate_entry(categorized_machines, machine)
                if duplicate_machine != None:
                    categorized_machines['DuplicateTenatacles'].append(machine)
                    categorized_machines['ActiveMachines'] -= 1

                categorized_machines['ListeningTentacles'].append(machine)
            
        if machine['IsDisabled'] == True:
            categorized_machines['DisabledMachines'].append(machine)
            continue

        categorized_machines['ActiveMachines'] +=1

        if machine['Status'] != "Online":
            categorized_machines['OfflineMachines'].append(machine)

        uri = '{0}/api/{1}/machines/{2}/tasks'.format(octopus_server_uri, space['Id'], machine['Id'])
        deployment_list = get_octopus_resource(uri, headers)

        if len(deployment_list) <= 0:
            categorized_machines['UnusedMachines'].append(machine)
            continue

        deployment_date = parse(deployment_list[0]['CompletedTime'])
        deployment_date = deployment_date.replace(tzinfo=None)

        # Calculate the date difference
        date_diff = current_date - deployment_date

        if date_diff.days > days_since_last_deployment:
            categorized_machines['OldMachines'].append(machine)
            
    
    return categorized_machines



octopus_server_uri = 'https://your.octopus.app'
octopus_api_key = 'API-YOURKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
categorized_machines = {
    'NotCountedMachines': [],
    'DisabledMachines': [],
    'ActiveMachines': 0,
    'OfflineMachines': [],
    'OldMachines': [],
    'TotalMachines': 0,
    'ListeningTentacles': [],
    'DuplicateTenatacles': [],
    'UnusedMachines': []
}
unsupported_communication_styles = ['None']
tentacle_communication_styles = ['TentaclePassive']
current_date = datetime.datetime.utcnow()
days_since_last_deployment = 90
include_machine_lists = False

# Get spaces
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)

# Loop through spaces
for space in spaces:
    categorized_machines = update_categorized_machines(categorized_machines, space, octopus_server_uri, headers, unsupported_communication_styles, tentacle_communication_styles)

print('This instance has a total of {0} targets across all spaces'.format(categorized_machines['TotalMachines']))
print('There are {0} cloud regions which are not counted'.format(len(categorized_machines['NotCountedMachines'])))
print('There are {0} disabled machines that are not counted'.format(len(categorized_machines['DisabledMachines'])))
print('There are {0} duplicate listening tentacles that are not counted (assuming youare using 2019.7.3+)'.format(len(categorized_machines['DuplicateTenatacles'])))
print('\n')
print('This leaves you with {0} active targets being counted against your license (this script is excluding the {1} duplicates in that active count'.format(categorized_machines['ActiveMachines'], len(categorized_machines['DuplicateTenatacles'])))
print('Of that combined number, {0} are showing up as offline'.format(len(categorized_machines['OfflineMachines'])))
print('Of that combined number, {0} have never had a deployment'.format(len(categorized_machines['UnusedMachines'])))
print('Of that combined number, {0} have not done a deployment in over {1} days'.format(len(categorized_machines['OldMachines']), days_since_last_deployment))

if include_machine_lists:
    print("Offline targets")
    for target in categorized_machines['OfflineMachines']:
        print("\t{0}".format(target['Name']))
    
    print("No deployments ever")
    for target in categorized_machines['UnusedMachines']:
        print("\t{0}".format(target['Name']))

    print ("No deployments in the last {0} days".format(days_since_last_deployment))
    for target in categorized_machines['OldMachines']:
        print("\t{0}".format(target['Name']))