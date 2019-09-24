##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$ProjectID = $OctopusParameters['Octopus.Project.ID']
$EnvironmentID = $OctopusParameters['Octopus.Environment.ID']
$TenantID = $OctopusParameters['Octopus.Deployment.Tenant.Id']

$ProjectDashboardReleases = (Invoke-WebRequest $OctopusURL/api/progression/$ProjectID -Method Get -Headers $header -UseBasicParsing).content | ConvertFrom-Json

$LastSuccessfullRelease = $ProjectDashboardReleases.Releases.Deployments.$EnvironmentId | ?{$_.state -eq "Success"} | ?{$_.TenantId -eq "$TenantID"} | select -First 1

$LastSuccessfullRelease.ReleaseVersion
