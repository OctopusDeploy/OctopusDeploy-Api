import json
import requests

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

space_name = "Default"
package_output_folder = '/path/to/output/package/to'
package_name = 'packagename'
package_version = '1.0.0.0'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
package = get_octopus_resource('{0}/{1}/packages/packages-{2}.{3}'.format(octopus_server_uri, space['Id'], package_name, package_version))

uri = '{0}/{1}/packages/packages-{2}.{3}/raw'.format(octopus_server_uri, space['Id'], package_name, package_version)
response = requests.get(uri, headers=headers)
response.raise_for_status()
package_output_file_path = '{0}/{1}.{2}{3}'.format(package_output_folder, package_name, package_version, package['FileExtension'])
f = open(package_output_file_path, "wb")
f.write(response.content)
f.close()
print('Downloaded package to \'{0}\''.format(package_output_file_path))