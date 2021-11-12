import json
import requests
from requests.api import get, head


def get_octopus_resource(uri, headers, skip_count=0):
    items = []
    skip_querystring = ""

    if '?' in uri:
        skip_querystring = '&skip='
    else:
        skip_querystring = '?skip='

    response = requests.get(
        (uri + skip_querystring + str(skip_count)), headers=headers)
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


octopus_server_uri = 'https://your.octopus.app'
octopus_api_key = 'API-KEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)
space_id = space['Id']

# Get executing tasks for space
uri = '{0}/api/tasks?states=Executing&spaces={1}&take=100000'.format(
    octopus_server_uri, space_id)
tasks = get_octopus_resource(uri, headers)

print('Found {0} executing tasks'.format(len(tasks)))
for task in tasks:
    duration = task['Duration']
    print('{0} has been executing for {1}'.format(task['Id'], task['Duration']))

