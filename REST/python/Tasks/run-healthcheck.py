import json
import requests
from requests.api import get, head

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
    if 'Items' in results.keys():
        items += results['Items']

        # Check to see if there are more results
        if (len(results['Items']) > 0) and (len(results['Items']) == results['ItemsPerPage']):
            skip_count += results['ItemsPerPage']
            items += get_octopus_resource(uri, headers, skip_count)

    else:
        return results

    
    # return results
    return items

def convert(seconds):
    seconds = seconds % (24 * 3600)
    hour = seconds // 3600
    seconds %= 3600
    minutes = seconds // 60
    seconds %= 60
      
    return "%d:%02d:%02d" % (hour, minutes, seconds)

octopus_server_uri = 'https://YourURL'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"
description = 'Health check started from Python script'
timeout_after_minutes = 5
machine_timeout_after_minutes = 5
environment_name = 'Development'
machine_names = [] # blank will check all machines in environment

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get environment
uri = '{0}/api/{1}/environments'.format(octopus_server_uri, space['Id'])
environments = get_octopus_resource(uri, headers)
environment = next((e for e in environments if e['Name'] == environment_name), None)

# Get machines to check
machines_to_check = []
uri = '{0}/api/{1}/machines?environmentids={2}'.format(octopus_server_uri, space['Id'], environment['Id'])
machines = get_octopus_resource(uri, headers)

for machine in machines:
    if len(machine_names) == 0:
        machines_to_check.append(machine['Id'])
    else:
        if machine['Name'] in machine_names:
            machines_to_check.append(machine['Id'])

# Construct payload
json_payload = {
    'SpaceId': space['Id'],
    'Name': 'Health',
    'Description': description,
    'Arguments': {
        'Timeout': convert((timeout_after_minutes * 60)),
        'MachineTimeout': convert((machine_timeout_after_minutes * 60)),
        'EnvironmentId': environment['Id'],
        'MachineIds': machines_to_check
    }
}

print (json_payload)

uri = '{0}/api/{1}/tasks'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=json_payload)
response.raise_for_status()