import json
from os import replace
import requests
from requests.api import get, head
import base64

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
certificate_name = 'MyCertificate'
certificate_file_path = 'path:\\to\\certificate.Pfx'
certificate_file_password = 'MyPassword'

# Get space
uri = '{0}/api/spaces'.format(octopus_server_uri)
spaces = get_octopus_resource(uri, headers)
space = next((x for x in spaces if x['Name'] == space_name), None)

# Open file
certificate_data = open(certificate_file_path, 'rb').read()
certificate_base64 = base64.b64encode(certificate_data)


# Get current certificiate
uri = '{0}/api/{1}/certificates'.format(octopus_server_uri, space['Id'])
certificates = get_octopus_resource(uri, headers)
certificate = next((c for c in certificates if c['Name'] == certificate_name), None)
test = certificate_base64.decode()

# Create json for upload
replacement_certificate = {
    'certificateData':  certificate_base64.decode().strip(),
    'password': certificate_file_password
}

# Replace certificate
uri = '{0}/api/{1}/certificates/{2}/replace'.format(octopus_server_uri, space['Id'], certificate['Id'])
response = requests.post(uri, headers=headers, json=replacement_certificate)
response.raise_for_status()