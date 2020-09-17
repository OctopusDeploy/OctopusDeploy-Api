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

space_name = 'Default'
project_name = 'Your project'
runbook_name = 'Your runbook'
runbook_snapshot_name = 'Snapshot HGYTH7J'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
project = get_by_name('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']), project_name)
runbook = get_by_name('{0}/{1}/runbooks/all'.format(octopus_server_uri, space['Id']), runbook_name)
runbook_process = get_octopus_resource('{0}/{1}/runbookProcesses/{2}'.format(octopus_server_uri, space['Id'], runbook['RunbookProcessId']))

runbook_selected_packages = []

for step in runbook_process['Steps']:
    for action in step['Actions']:
        if action['Packages'] is None:
            continue
        for action_package in action['Packages']:
            package_id = action_package['PackageId']
            package_details = get_octopus_resource('{0}/{1}/feeds/{2}/packages/versions?packageId={3}&take=1'.format(octopus_server_uri, space['Id'], action_package['FeedId'], package_id))
            package_version = package_details['Items'][0]['Version']
            selected_package = {
                'ActionName': action['Name'],
                'Version': package_version,
                'PackageReferenceName': ""
            }
            runbook_selected_packages.append(selected_package)

snapshot_to_publish = {
    'ProjectId': project['Id'],
    'RunbookId':runbook['Id'],
    'Name': runbook_snapshot_name,
    'SelectedPackages': runbook_selected_packages
}

uri = '{0}/{1}/runbookSnapShots?publish=true'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=snapshot_to_publish)
response.raise_for_status()