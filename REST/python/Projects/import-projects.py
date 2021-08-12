import json
import requests
from requests.api import get, head
from datetime import datetime
import time

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
sourceSpaceName = "Default"
destinationSpaceName = "DestinationSpace"
exportTaskId = "ServerTasks-XXXX" # from the export operation
importTaskPassword = "MyFantasticPassword"
importTaskWaitForFinish = True
importTaskCancelInSeconds = 300

# Get destination space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
destinationSpace = next((x for x in spaces if x['Name'] == destinationSpaceName), None)

# Get source space
sourceSpace = next((x for x in spaces if x['Name'] == sourceSpaceName), None)

# Define body of request
importBody = {
    'ImportSource': {
        'Type': 'space', # must be lower case
        'SpaceId': sourceSpace['Id'],
        'TaskId' : exportTaskId
    },
    'Password': {
        'HasValue': True,
        'NewValue': importTaskPassword
    }
}

# Execute transfer
uri = '{0}/api/{1}/projects/import-export/import'.format(octopus_server_uri, destinationSpace['Id'])
print ('Kicking off import from {0} to {1}'.format(sourceSpaceName, destinationSpaceName))
response = requests.post(uri, headers=headers, json=importBody)
response.raise_for_status()

# Get results
results = json.loads(response.content.decode('utf-8'))
importTaskId = results['TaskId']
print ('The task id of the new task is: {0}'.format(importTaskId))

if importTaskWaitForFinish:
    start_time = datetime.now()
    current_time = datetime.now()
    
    date_difference = current_time - start_time
    number_of_waits = 0

    while date_difference.seconds < importTaskCancelInSeconds:
        print ('Waiting 5 seconds')
        time.sleep(5)
        uri = '{0}/api/{1}/tasks/{2}'.format(octopus_server_uri, destinationSpace['Id'], importTaskId)
        response = requests.get(uri, headers=headers)
        response.raise_for_status()

        results = json.loads(response.content.decode('utf-8'))
        
        if results['State'] == 'Success':
            print ('The task has finished successfully')
            exit(0)

        elif results['State'] == 'Failed' or results['State'] == 'Cancelled':
            print ('The task finished with a status of {0}'.format(results['State']))
            exit(1)

        number_of_waits += 1

        if number_of_waits >= 10:
            print ('The task is currently {0}'.format(results['State']))
            number_of_waits = 0
        else:
            print ('The task is currently {0}'.format(results['State']))
        
        if results['StartTime'] == None or results['StartTime'] == '':
            print ('The task is still queued, let us wait a bit longer')
            start_time = datetime.now()
        
        current_time = datetime.now()
        date_difference = current_time - start_time    

  
    print ('The cancel timeout has been reached, cancelling the export task')
    uri = '{0}/api/{1}/tasks/{2}'.format(octopus_server_uri, destinationSpace['Id'], importTaskId)
    response = requests.get(uri, headers=headers)
    response.raise_for_status()