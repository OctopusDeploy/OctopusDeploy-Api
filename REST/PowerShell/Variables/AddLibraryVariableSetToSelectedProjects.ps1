$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$librarySetName = "MyLibrarySet"
$spaceName = "MySpace"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get library set
$librarySet = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header) | Where-Object {$_.Name -eq $librarySetName}

# Add the libarary set
$project.IncludedLibraryVariableSetIds += $librarySet.Id

# Update the project
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)" -Headers $header -Body ($project | ConvertTo-Json -Depth 10)
