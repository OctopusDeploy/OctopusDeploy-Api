$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

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
$runbookTriggerDaysOfWeekToRun = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

# Specify the start time to run the runbook each day in the format yyyy-MM-ddTHH:mm:ss.fffZ
# See https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings?view=netframework-4.8

$runbookTriggerStartTime = "2021-07-22T09:00:00.000Z"

# Script variables
$runbookEnvironmentIds = @()

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get runbook
$runbooks = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header 
$runbook = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }

# Get environments for runbook trigger
foreach($runbookEnvironmentName in $runbookEnvironmentNames) {
    $environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($runbookEnvironmentName))&skip=0&take=100" -Headers $header 
    $environment = $environments.Items | Where-Object { $_.Name -eq $runbookEnvironmentName } | Select-Object -First 1
    $runbookEnvironmentIds += $environment.Id
}

# Create a runbook trigger
$body = @{
    ProjectId = $project.Id;
    Name = $runbookTriggerName;
    Description = $runbookTriggerDescription;
    IsDisabled = $False;
    Filter = @{
        Timezone = $runbookTriggerTimezone;
        FilterType = "OnceDailySchedule";
        DaysOfWeek = @($runbookTriggerDaysOfWeekToRun);
        StartTime = $runbookTriggerStartTime;
    };
    Action = @{
        ActionType = "RunRunbook";
        RunbookId = $runbook.Id;
        EnvironmentIds = @($runbookEnvironmentIds);
    };
}

# Convert body to JSON
$body = $body | ConvertTo-Json -Depth 10

# Create runbook scheduled trigger
$runbookScheduledTrigger = Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/projecttriggers" -Body $body -Headers $header 

Write-Host "Created runbook trigger: $($runbookScheduledTrigger.Id) ($runbookTriggerName)"