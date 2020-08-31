# Octopus Url
$OctopusUrl = "https://your-octopus-url"

# API Key
$APIKey = "API-XXXXXXXXX"

# Space where machines exist
$spaceName = "Default" 

$header = @{ "X-Octopus-ApiKey" = $APIKey }

# Get SpaceId
Write-Host "Getting list of all spaces: $OctopusUrl/api/Spaces?skip=0&take=100000"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$space = $spaceList.Items | Where-Object { $_.Name -eq $spaceName} | Select-Object -First 1
$spaceId = $space.Id

# Get List of All Environments for Space

$environmentUrl = "$OctopusUrl/api/$spaceId/environments?skip=0&take=100000"

Write-Host "Getting list of environments: $environmentUrl"
$environmentResource = (Invoke-RestMethod $environmentUrl -Headers $header)
$environments = $environmentResource.Items

$deploymentsUrl = "$OctopusUrl/api/$spaceId/deployments?skip=0&take=100000"
Write-Host "Getting list of deployments: $deploymentsUrl"
$deploymentsResource = (Invoke-RestMethod $deploymentsUrl -Headers $header)
$deployments = $deploymentsResource.Items

$foundEnvironments = @()
foreach ($deployment in $deployments) {
    $deploymentEnvironmentId = $deployment.EnvironmentId
    if( -not $foundEnvironments.Contains($deploymentEnvironmentId)) {
        $foundEnvironments += "$deploymentEnvironmentId"
    }
}

# Just the Ids for Space Environments
$spaceEnvironmentids = $environments | ForEach-Object {"$($_.Id)"}

$result = $spaceEnvironmentids | Where-Object {!($foundEnvironments -contains $_)}
$total = $result.Count
Write-Host "Found $total environments without deployments." 
if($result.Count -gt 0) {
    $tempFile = [System.IO.Path]::GetTempFileName() 
    $result | Out-File -append $tempFile
    Write-Host "Written environments with no deployments to: $tempFile"
}
