# This script will add the specified external role to a team
# External roles are used by authentication providers which support groups
# to automatically place users into a group when they are created

$OctopusURL = "" # URL of Octopus Server
$OctopusAPIKey = "" # API Key to authenticate to Octopus Server
$TeamName = "Octopus Administrators"
$ExternalRoleId = "NewRoleId"
$ExternalRoleDescription = "New role description"
$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

#get the teams
$progressPreference = 'silentlyContinue'
$teams = Invoke-WebRequest "$OctopusURL/api/teams" -Headers $header | select -ExpandProperty Content | ConvertFrom-Json
$team = $teams.Items | Where-Object { $_.Name -eq $TeamName }

$team.ExternalSecurityGroups += @{
  DisplayIdAndName = $true
  DisplayName = $ExternalRoleId
  Id = $ExternalRoleId
}

Invoke-WebRequest "$OctopusURL/api/teams/$($team.Id)" -Method PUT -Headers $header -Body ($team | ConvertTo-Json)
