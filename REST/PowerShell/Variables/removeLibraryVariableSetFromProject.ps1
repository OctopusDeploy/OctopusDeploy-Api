$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-x"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = ""
$spaceName = ""
$librarySetName = ""

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get library set
$librarySet = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header) | Where-Object {$_.Name -eq $librarySetName}

# New empty array to house modified library variable sets
$modifiedLibraryVariableSetIds = @()

# Add the library sets that don't match to the modified project object
foreach ($libraryVariableSetId in $project.IncludedLibraryVariableSetIds) {
    if ($librarySet.Id -ne $libraryVariableSetId) {
        $modifiedLibraryVariableSetIds += $libraryVariableSetId
    }
} 

$project.IncludedLibraryVariableSetIds = $modifiedLibraryVariableSetIds

# Update the project using the modified project object
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)" -Headers $header -Body ($project | ConvertTo-Json -Depth 10)
