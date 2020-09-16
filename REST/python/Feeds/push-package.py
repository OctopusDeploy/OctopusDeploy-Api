import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = "Default"
package_folder = '/folder/containing/package/'
package_name = 'Package.Name.1.2.3.zip'

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

with open('{0}{1}'.format(package_folder, package_name), 'rb') as package:
    uri = '{0}/{1}/packages/raw?replace=false'.format(octopus_server_uri, space['Id'])
    files = {
        'fileData': (package_name, package, 'multipart/form-data', {'Content-Disposition': 'form-data'})
    }

    response = requests.post(uri, headers=headers, files=files)
    response.raise_for_status()