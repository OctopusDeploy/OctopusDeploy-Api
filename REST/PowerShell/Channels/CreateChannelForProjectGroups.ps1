$ErrorActionPreference = "Stop";

####
## Define working variables
####

$octopusURL = "http://<Your _Url>"
$octopusAPIKey = "API-<Key>"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "spaceName"
$channelName = "channelName"
$projectGroupName = "Project Group Name"


# What-If flag (set to true to test changes without comitting them)
$whatIf = $false

####
## Perform API Calls
####

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get new lifecycle
$newLifecycle = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/lifecycles/all" -Headers $header) | Where-Object { $_.Name -eq $newLifecycleName }

# Get project groups for space
$projectGroup = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projectgroups/all" -Headers $header) | Where-Object { $_.Name -eq $projectGroupName }

#Get projects for specified project group
$projectList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projectgroups/$($projectGroup.Id)/projects?skip=0&take=100"  -Headers $header  )



foreach ($project in $projectList.Items.Id) {
  
    $jsonPayload = @{
    ProjectId = $project;
    SpaceId = $space.Id;
    Name = $channelName;
    LifecycleId = "<LifecycleID>"; #can be fetched by using the script Fetch LiecycleId's in the folder Lifecycle
    Description = "";
    IsDefault = $False;
     }
   
    if (!$whatIf) {
        Write-Host -ForegroundColor Green "`Creating Project Channel for $($project)"
        Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/channels" -Headers $header  -Body ($jsonPayload | ConvertTo-Json -Depth 10)
    }
    else {
        Write-Host -ForegroundColor Yellow "`tWhat if set to true - would update project channel for $($project)"
    }
}
