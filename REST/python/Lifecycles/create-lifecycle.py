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

# Define Octopus server variables
octopus_server_uri = 'https://your.octopus.app'
octopus_api_key = 'API-YOUR-KEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"
lifecycle_name = "MyLifecycle"

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Get lifecycles
uri = '{0}/api/{1}/lifecycles'.format(octopus_server_uri, space['Id'])
lifecycles = get_octopus_resource(uri, headers)
lifecycle = next((x for x in lifecycles if x['Name'] == lifecycle_name), None)

# Check to see if lifecycle already exists
if None == lifecycle:
    # Create new lifecycle
    lifecycle = {
        'Id': None,
        'Name': lifecycle_name,
        'SpaceId': space['Id'],
        'Phases': [],
        'ReleaseRetentionPolicy': {
            'ShouldKeepForever': True,
            'QuantityToKeep': 0,
            'Unit': 'Days'
        },
        'TentacleRetentionPolicy': {
            'ShouldKeepForever': True,
            'QuantityToKeep': 0,
            'Unit': 'Days'
        },
        'Links': None
    }

    response = requests.post(uri, headers=headers, json=lifecycle)
    response.raise_for_status()
else:
    print ('{0} already exists.'.format(lifecycle_name))