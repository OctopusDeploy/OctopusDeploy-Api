##CONFIG
$octopusURL = "https://YOUR_OCTOPUS_SERVER" #Octopus URL
$octopusAPIKey = "API-1234123412341234" #Octopus API Key
$spaceName = "Default"

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}
$projects = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects?take=2000000" -Headers $header).items

foreach ($project in $projects)
{
    Write-Host "`nChecking Project: $($project.Name)"
    $ProjectDashboardReleases = (Invoke-WebRequest $octopusURL/api/progression/$($project.Id) -Method Get -Headers $header).content | ConvertFrom-Json
    foreach ($environment in $ProjectDashboardReleases.Environments)
    {
        $LastSuccessfulRelease = $ProjectDashboardReleases.Releases.Deployments.$($environment.Id) | ?{$_.state -eq "Success"} | select -First 1
        Write-Output "Last Successful Release in $($environment.Name): `t$($LastSuccessfulRelease.CompletedTime)"
    }
}

