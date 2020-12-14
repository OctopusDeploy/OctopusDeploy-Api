$octopusApiKey = "YOUR API KEY"
$octopusUrl = "YOUR URL"
$spaceName = "Default"
$environmentName = "Production"

$header = @{"X-Octopus-ApiKey" = "$octopusApiKey" }

$spaceList = Invoke-RestMethod -Uri "$octopusUrl/api/spaces?partialName=$([System.Web.HTTPUtility]::UrlEncode($spaceName))&skip=0&take=1" -Headers $header
$space = $spaceList.Items[0]

$dashboardInformation = Invoke-RestMethod -Uri "$octopusUrl/api/$($space.Id)/dashboard?highestLatestVersionPerProjectAndEnvironment=true" -Headers $header
$environmentToUse = $dashboardInformation.Environments | Where-Object {$_.Name -eq $environmentName}
$deploymentsToEnvironment = @($dashboardInformation.Items | Where-Object {$_.EnvironmentId -eq $environmentToUse.Id})

foreach ($deployment in $deploymentsToEnvironment)
{
    $project = $dashboardInformation.Projects | Where-Object { $_.Id -eq $deployment.ProjectId }
    $tenantName = $null

    if ($null -ne $deployment.TenantId)
    {        
        $tenant = $dashboardInformation.Tenants | Where-Object { $_.Id -eq $deployment.TenantId }
        $tenantName = $tenant.Name
    }

    Write-Host "$($project.Name) $tenantName $($deployment.ReleaseVersion)"
}