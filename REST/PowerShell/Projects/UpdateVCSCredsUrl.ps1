$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-####"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "Project Name"
$spaceId = "Spaces-##"
$gitCredId = "GitCredentials-##" # From Library > Git Credentials
$gitRepoUrl = "https://github.com/<user>/<repo>.git"

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($spaceId)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Change from Username/Password at the project level to a Git Credential in the library (optional, but Git Creds are much easier - can change back via UI if desired)
$project.PersistenceSettings.Credentials.Type = "Reference"
$project.PersistenceSettings.Credentials.PSObject.Properties.Remove("Username")
$project.PersistenceSettings.Credentials.PSObject.Properties.Remove("Password")
$project.PersistenceSettings.Credentials | Add-Member -NotePropertyName Id -NotePropertyValue $gitCredId

# Update VCS Github repo URL
$project.PersistenceSettings.Url = $gitRepoUrl

# Commit changes to Octopus project
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($spaceId)/projects/$($project.Id)" -Headers $header -Body ($project | ConvertTo-Json -Depth 100)
