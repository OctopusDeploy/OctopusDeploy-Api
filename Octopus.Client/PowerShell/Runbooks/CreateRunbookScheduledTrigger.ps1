# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"

$spaceName = "Default"
$projectName = "MyProject"
$runbookName = "MyRunbook"

# Specify runbook trigger name
$runbookTriggerName = "RunbookTriggerName"

# Specify runbook trigger description
$runbookTriggerDescription = "RunbookTriggerDescription"

# Specify which environments the runbook should run in
$runbookEnvironmentNames = @("Development")

# What timezone do you want the trigger scheduled for
$runbookTriggerTimezone = "GMT Standard Time"

# Remove any days you don't want to run the trigger on
$runbookTriggerDaysOfWeekToRun = [Octopus.Client.Model.DaysOfWeek]::Monday -bor [Octopus.Client.Model.DaysOfWeek]::Tuesday -bor [Octopus.Client.Model.DaysOfWeek]::Wednesday -bor [Octopus.Client.Model.DaysOfWeek]::Thursday -bor [Octopus.Client.Model.DaysOfWeek]::Friday -bor [Octopus.Client.Model.DaysOfWeek]::Saturday -bor [Octopus.Client.Model.DaysOfWeek]::Sunday

# Specify the start time to run the runbook each day in the format yyyy-MM-ddTHH:mm:ss.fffZ
# See https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings?view=netframework-4.8

$runbookTriggerStartTime = "2021-07-22T09:00:00.000Z"

# Script variables
$runbookEnvironmentIds = @()

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Get project
$project = $repositoryForSpace.Projects.FindByName($projectName);

# Get runbook
$runbook = $repositoryForSpace.Runbooks.FindByName($runbookName);

foreach($environmentName in $runbookEnvironmentNames) {
    $environment = $repositoryForSpace.Environments.FindByName($environmentName);
    $runbookEnvironmentIds += $environment.Id
}

$runbookScheduledTrigger = New-Object Octopus.Client.Model.ProjectTriggerResource

$runbookScheduledTriggerFilter = New-Object Octopus.Client.Model.Triggers.ScheduledTriggers.OnceDailyScheduledTriggerFilterResource
$runbookScheduledTriggerFilter.Timezone = $runbookTriggerTimezone
$runbookScheduledTriggerFilter.StartTime = (Get-Date -Date $runbookTriggerStartTime)
$runbookScheduledTriggerFilter.DaysOfWeek = $runbookTriggerDaysOfWeekToRun

$runbookScheduledTriggerAction = New-Object Octopus.Client.Model.Triggers.RunRunbookActionResource
$runbookScheduledTriggerAction.RunbookId = $runbook.Id
$runbookScheduledTriggerAction.EnvironmentIds = New-Object Octopus.Client.Model.ReferenceCollection($runbookEnvironmentIds)

$runbookScheduledTrigger.ProjectId = $project.Id
$runbookScheduledTrigger.Name = $runbookTriggerName
$runbookScheduledTrigger.Description = $runbookTriggerDescription
$runbookScheduledTrigger.IsDisabled = $False
$runbookScheduledTrigger.Filter = $runbookScheduledTriggerFilter
$runbookScheduledTrigger.Action = $runbookScheduledTriggerAction

$createdRunbookTrigger = $repositoryForSpace.ProjectTriggers.Create($runbookScheduledTrigger);
Write-Host "Created runbook trigger: $($createdRunbookTrigger.Id) ($runbookTriggerName)"