$ErrorActionPreference = "Stop";
# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "My Projects"
$runbookName = "My runbook"
$environmentName = "Development"
$fileDownloadPath = "/path/to/download/artifact.txt"

# Note: Must include file extension in name.
$fileNameForOctopus = "artifact_filename_in_octopus.txt" 

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get environment
$environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environmentName))&skip=0&take=100" -Headers $header 
$environment = $environments.Items | Where-Object { $_.Name -eq $environmentName }

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get runbook
$runbooks = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header 
$runbook = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }

# Get latest runbook run to that environment
$tasks = Invoke-RestMethod -Uri "$octopusURL/api/tasks?skip=0&runbook=$($runbook.Id)&project=$($project.Id)&spaces=$($space.Id)&environment=$($environment.Id)&includeSystem=false" -Headers $header 
$task = $tasks.Items | Where-Object {$_.State -eq "Success"} | Select-Object -First 1

$artifacts = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/artifacts?regarding=$($task.Id)" -Headers $header
$artifact = $artifacts.Items | Where-Object {$_.Filename -eq $fileNameForOctopus}

Write-Host "Getting file content"
Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/artifacts/$($artifact.Id)/content" -Headers $header -OutFile $fileDownloadPath
Write-Host "File content written to $fileDownloadPath"
