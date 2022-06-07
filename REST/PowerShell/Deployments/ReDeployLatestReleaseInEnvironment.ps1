$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "http://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$projectName = "YourProject"
$environmentName = "DEV1"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

Write-Host "The spaceId for $spaceName is $($spaceId)"

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }
$projectId = $project.Id

Write-Host "The projectId for $spaceName is $($projectId)"

# Get environment
$environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environmentName))&skip=0&take=100" -Headers $header 
$environment = $environments.Items | Where-Object { $_.Name -eq $environmentName } | Select-Object -First 1
$environmentId = $environment.Id

Write-Host "The environmentId for $environmentName is $environmentId"
$progressionInformation = Invoke-RestMethod "$octopusURL/api/$spaceId/projects/$projectId/progression" -Headers $header

Write-Host "Found $($progressionInformation.Releases.Length) releases"
$releaseId = ""

foreach ($release in $progressionInformation.Releases) {        
    foreach ($deployEnv in $release.Deployments) {            
        if (Get-Member -InputObject $deployEnv -Name $environmentId -MemberType Properties) {
            $releaseId = $release.Release.Id
            break
        }            
    }

    if ([string]::IsNullOrWhiteSpace($releaseId) -eq $False) {
        break
    }
}

if ([string]::IsNullOrWhiteSpace($releaseId) -eq $True) {
    Write-Error "A release couldn't be found deployed to $environmentName!"
    return
}

Write-Host "The most recent release for $ProjectName in the $EnvironmentName Environment is $releaseId"

$bodyRaw = @{
    EnvironmentId            = "$environmentId"
    ExcludedMachineIds       = @()
    ForcePackageDownload     = $False
    ForcePackageRedeployment = $false
    FormValues               = @{}
    QueueTime                = $null
    QueueTimeExpiry          = $null
    ReleaseId                = "$releaseId"
    SkipActions              = @()
    SpecificMachineIds       = @()
    TenantId                 = $null
    UseGuidedFailure         = $false
} 

$bodyAsJson = $bodyRaw | ConvertTo-Json

$redeployment = Invoke-RestMethod "$OctopusURL/api/$SpaceId/deployments" -Headers $header -Method Post -Body $bodyAsJson -ContentType "application/json"
$taskId = $redeployment.TaskId
$deploymentIsActive = $true

do {
    $deploymentStatus = Invoke-RestMethod "$OctopusURL/api/tasks/$taskId/details?verbose=false" -Headers $header
    $deploymentStatusState = $deploymentStatus.Task.State

    if ($deploymentStatusState -eq "Success" -or $deploymentStatusState -eq "Failed") {
        $deploymentIsActive = $false
    }
    else {
        Write-Host "Deployment is still active...checking again in 5 seconds"
        Start-Sleep -Seconds 5
    }

} While ($deploymentIsActive)

Write-Host "Redeployment has finished"