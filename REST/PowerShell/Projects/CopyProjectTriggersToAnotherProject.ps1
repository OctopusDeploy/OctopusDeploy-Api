$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$sourceProjectName = "Source project"
$destProjectName = "Destination project"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get source project
$sourceProjects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($sourceProjectName))&skip=0&take=100" -Headers $header 
$sourceProject = $sourceProjects.Items | Where-Object { $_.Name -eq $sourceProjectName }

# Get source project triggers
$sourceProjectTriggers = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($sourceProject.Id)/triggers" -Headers $header

# Get destination project
$destProjects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($destProjectName))&skip=0&take=100" -Headers $header 
$destProject = $destProjects.Items | Where-Object { $_.Name -eq $destProjectName }

# Get destination project triggers
$destProjectTriggers = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($destProject.Id)/triggers" -Headers $header

# Loop through source triggers
foreach ($projectTrigger in $sourceProjectTriggers.Items) {
    $matchingDestTriggers = @($destProjectTriggers.Items | Where-Object { $_.Name -ieq $projectTrigger.Name })
    if ($matchingDestTriggers.Count -gt 0) {
        Write-Warning "'$($projectTrigger.Name)' already exists in '$($destProjectName)'"
    }
    else {
        Write-Host "Trigger '$($projectTrigger.Name)' doesnt exist in $($destProjectName), creating."
        $projectTrigger.Id = $null
        $projectTrigger.Links = $null
        # IMPORTANT, switch project Id :)
        $projectTrigger.ProjectId = $destProject.Id
        $response = Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/projects/$($destProject.Id)/triggers" -Body ($projectTrigger | ConvertTo-Json -Depth 10) -Headers $header
        Write-Verbose "Trigger creation response: $response"
    }
}