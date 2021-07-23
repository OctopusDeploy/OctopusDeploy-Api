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

def get_item_by_name(uri, name):
    resources = get_octopus_resource(uri)
    return next((x for x in resources['Items'] if x['Name'] == name), None)

# Define variables
space_name = 'Default'
project_name = 'Your Project Name'
runbook_name = 'Your runbook name'
runbook_trigger_name = 'Your runbook trigger name'
runbook_trigger_description = 'Your runbook trigger description'
runbook_trigger_environments = ['Development', 'Test']
runbook_trigger_timezone = 'GMT Standard Time'
runbook_trigger_schedule_days_of_week = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
runbook_trigger_schedule_start_time = '2021-07-22T09:00:00.000Z'

space = get_by_name('{0}/spaces/all'.format(octopus_server_uri), space_name)
project = get_by_name('{0}/{1}/projects/all'.format(octopus_server_uri, space['Id']), project_name)
runbook = get_item_by_name('{0}/{1}/projects/{2}/runbooks'.format(octopus_server_uri, space['Id'], project['Id']), runbook_name)
environments = get_octopus_resource('{0}/{1}/environments/all'.format(octopus_server_uri, space['Id']))

runbook_environment_ids = [environment['Id'] for environment in environments if environment['Name'] in runbook_trigger_environments]

scheduled_runbook_trigger = {
    'ProjectId': project['Id'],
    'Name': runbook_trigger_name,
    'Description': runbook_trigger_name,
    'IsDisabled': False,
    'Filter': {
        'Timezone': runbook_trigger_timezone,
        'FilterType': 'OnceDailySchedule',
        'DaysOfWeek': runbook_trigger_schedule_days_of_week,
        'StartTime': runbook_trigger_schedule_start_time
    },
    'Action': {
        'ActionType': 'RunRunbook',
        'RunbookId': runbook['Id'],
        'EnvironmentIds': runbook_environment_ids
    }
}

uri = '{0}/{1}/projecttriggers'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=scheduled_runbook_trigger)
response.raise_for_status()