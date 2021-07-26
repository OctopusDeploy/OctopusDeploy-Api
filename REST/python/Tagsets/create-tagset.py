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

octopus_server_uri = 'https://YourURL'
octopus_api_key = 'API-YourAPIKey'
headers = {'X-Octopus-ApiKey': octopus_api_key}
space_name = "Default"
tagset_name = "MyTagset"
tagset_description = "My description"
tags = []
tag = {
    'Id': None,
    'Name': 'Tag1',
    'Color': '#ECAD3F',
    'Description': 'Tag Description',
    'CanonicalTagName': None
}

tags.append(tag)

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Check to see if tagset exists
uri = '{0}/api/{1}/tagsets?partialName={2}'.format(octopus_server_uri, space['Id'], tagset_name)
tagsets = get_octopus_resource(uri, headers)

if len(tagsets) == 0:
    tagset = {
        'Name': tagset_name,
        'Description': tagset_description,
        'Tags': tags
    }

    uri = '{0}/api/{1}/tagsets'.format(octopus_server_uri, space['Id'])
    response = requests.post(uri, headers=headers, json=tagset)
    response.raise_for_status()    
else:
    print ('{0} already exists!'.format(tagset_name))