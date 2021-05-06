$ErrorActionPreference = "Stop";
<#
Produces output for all project scheduled triggers on an Octopus instance in the following format:

[{
    "ProjectName": "Artifactory Sample Management",
    "Timezone": "UTC",
    "ActionType": "RunRunbook",
    "MonthlyScheduleType": "DateOfMonth",
    "StartTime": "2021-03-15T06:00:00Z",
    "FilterType": "DaysPerMonthSchedule",
    "RunbookId": "Runbooks-1081",
    "DateOfMonth": "30",
    "SpaceName": "Octopus Admin"
  },
  {
    "StartTime": "2021-02-15T07:00:00Z",
    "DaysOfWeek": [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday"
    ],
    "SpaceName": "Octopus Admin",
    "RunbookId": "Runbooks-1082",
    "ProjectName": "Artifactory Sample Management",
    "ActionType": "RunRunbook",
    "FilterType": "OnceDailySchedule",
    "Timezone": "UTC"
  },
  {
    "FilterType": "CronExpressionSchedule",
    "ActionType": "RunRunbook",
    "RunbookId": "Runbooks-26",
    "CronExpression": "0 0 * * * *",
    "SpaceName": "Monitoring",
    "ProjectName": "Monitoring and Remediation with Runbooks"
  }]
#>

$octopusURL = "https://youroctopus.instance.app/"
$octopusAPIKey = "API-xxxxxx"

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$triggers = New-Object -TypeName 'System.Collections.ArrayList';

# Get spaces
$spaces = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header
    
foreach ($space in $spaces) {
    try {
        # Get projects
        $projects = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) 

        foreach ($project in $projects) {
            
            # Get project triggers
            $projectTriggers = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/triggers" -Headers $header

            # Loop through triggers
            foreach ($projectTrigger in $projectTriggers.Items)
            {
                if ($projectTrigger.Filter.FilterType -eq "MachineFilter"){
                    continue;
                }

                if ($projectTrigger.Filter.FilterType -eq "CronExpressionSchedule") {
                    $triggers.Add(@{
                        SpaceName = $space.Name;
                        ProjectName = $project.Name;
                        ActionType = $projectTrigger.Action.ActionType;
                        RunbookId = $projectTrigger.Action.RunbookId;
                        FilterType = $projectTrigger.Filter.FilterType;
                        CronExpression = $projectTrigger.Filter.CronExpression;
                    })
                } 
                
                If ($projectTrigger.Filter.FilterType -eq "OnceDailySchedule"){
                    $triggers.Add(@{
                        SpaceName = $space.Name;
                        ProjectName = $project.Name;
                        ActionType = $projectTrigger.Action.ActionType;
                        RunbookId = $projectTrigger.Action.RunbookId;
                        FilterType = $projectTrigger.Filter.FilterType;
                        StartTime = $projectTrigger.Filter.StartTime;
                        DaysOfWeek = $projectTrigger.Filter.DaysOfWeek;
                        Timezone = $projectTrigger.Filter.Timezone;
                    })
                }
                If ($projectTrigger.Filter.FilterType -eq "DaysPerMonthSchedule"){
                    $triggers.Add(@{
                        SpaceName = $space.Name;
                        ProjectName = $project.Name;
                        ActionType = $projectTrigger.Action.ActionType;
                        RunbookId = $projectTrigger.Action.RunbookId;
                        FilterType = $projectTrigger.Filter.FilterType;
                        StartTime = $projectTrigger.Filter.StartTime;
                        DateOfMonth = $projectTrigger.Filter.DateOfMonth;
                        MonthlyScheduleType = $projectTrigger.Filter.MonthlyScheduleType;
                        Timezone = $projectTrigger.Filter.Timezone;
                    })
                }
                
            }
        }
    }
    catch {
        Write-Host "Space $($space.Name) is inaccessible"
    }
}

# Write out to a file.
($triggers | ConvertTo-Json) > out.json
