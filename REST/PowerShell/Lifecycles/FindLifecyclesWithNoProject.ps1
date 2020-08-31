# Octopus Url
$OctopusUrl = "https://your-octopus-url"

# API Key
$APIKey = "API-XXXXXXXXX"

# Space where machines exist
$spaceName = "Default" 

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces: $OctopusUrl/api/Spaces?skip=0&take=100000"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$space = $spaceList.Items | Where-Object { $_.Name -eq $spaceName} | Select-Object -First 1
$spaceId = $space.Id

$lifecycleUrl = "$OctopusUrl/api/$spaceId/lifecycles?skip=0&take=100000"
Write-Host "Getting list of all lifecycles in space: $lifecycleUrl"

$lifecycles = (Invoke-RestMethod $lifecycleUrl -Headers $header)

$lifecyclesWithoutProjects = @()
foreach ($lifecycle in $lifecycles.Items) {
    $lifecycleName = $lifecycle.Name
    $lifecycleId = $lifecycle.Id
    Write-Host "Checking lifecycle usage for: $lifecycleName ($lifecycleId)" -ForegroundColor White
    $lifecycleProjectUrl = "$OctopusUrl/api/$spaceId/lifecycles/$lifecycleId/projects"
    $lifecycleProjects = (Invoke-RestMethod $lifecycleProjectUrl -Headers $header)
    $projectCount = $lifecycleProjects.Items.Count
    if($projectCount -eq 0) {
        $lifecycleDesc = "$lifecycleName ($lifecycleId)"
        Write-Host "$lifecycleDesc" -ForegroundColor DarkYellow
        $lifecyclesWithoutProjects += "$lifecycleName ($lifecycleId)"
    }
}

$totalFound = $lifecyclesWithoutProjects.Count
Write-Host "Total Lifecyles with no projects: $totalFound"

if ($totalFound -gt 0) {   
    $tempFile = [System.IO.Path]::GetTempFileName() 
    $lifecyclesWithoutProjects | Out-File -append $tempFile
    Write-Host "Found the following lifecycles with no projects usage:" -ForegroundColor Red
    foreach ($lifecycle in $lifecyclesWithoutProjects) {
        Write-Host $lifecycle
    }
    Write-Host "Written projects with no lifecycle to: $tempFile"
}