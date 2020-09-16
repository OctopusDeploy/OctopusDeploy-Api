import json
import requests
octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}
def get_octopus_resource(uri):
    response = requests.get(uri, headers=headers)
    response.raise_for_status()
    return json.loads(response.content.decode('utf-8'))
space_name = 'Default'
project_name = 'Your project name'
role_name = 'Your target role'
step_name = 'New run a script step'
spaces = get_octopus_resource('{0}/spaces/all'.format(octopus_server_uri))
space = next((x for x in spaces if x['Name'] == space_name), None)
projects = get_octopus_resource('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']))
project = next((x for x in projects if x['Name'] == project_name), None)
uri = '{0}/{1}/deploymentprocesses/{2}'.format(octopus_server_uri, space['Id'], project['DeploymentProcessId'])
process = get_octopus_resource(uri)
process['Steps'].append({
    'Name': step_name,
    'Properties': {
        'Octopus.Action.TargetRoles': role_name
    },
    'Condition': 'Success',
    'StartTrigger': 'StartAfterPrevious',
    'PackageRequirement': 'LetOctopusDecide',
    'Actions': [{
        'ActionType': 'Octopus.Script',
        'WorkerPoolId': None,
        'Container': {'Image': None, 'FeedId': None},
        'WorkerPoolVariable': None,
        'Name': step_name,
        'Environments': [],
        'Channels': [],
        'TenantTags': [],
        'Properties': {
            'Octopus.Action.RunOnServer': 'false',
            'Octopus.Action.EnabledFeatures': '',
            'Octopus.Action.Script.ScriptSource': 'Inline',
            'Octopus.Action.Script.Syntax': 'Python',
            'Octopus.Action.Script.ScriptFilename': None,
            'Octopus.Action.Script.ScriptBody': 'print("Hello world")'
        }
    }]
})
response = requests.put(uri, headers=headers, json=process)
response.raise_for_status()