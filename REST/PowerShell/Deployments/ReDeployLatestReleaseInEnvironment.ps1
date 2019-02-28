###CONFIG###
$OctopusURL = #Your Octopus URL 
$APIKey = #API Key of someone with permissions to redeploy
$SpaceId = #Current SpaceId of the deployment 
$ProjectName = #The Name of the project to look for
$EnvironmentName = #The name of the environment to redeploy to

###PROCESS###
$header = @{ "X-Octopus-ApiKey" = $APIKey }

##GetProjectId
$project = (Invoke-WebRequest "$OctopusURL/api/$spaceId/projects?name=$projectName&skip=0&take=1" -Headers $header).content | ConvertFrom-Json
$projectId = $project.Items[0].Id

Write-Host "The projectId for $ProjectName is $projectId"

$stagingEnvironment = (Invoke-WebRequest "$OctopusURL/api/$spaceId/environments?name=$EnvironmentName&skip=0&take=1" -Headers $header).content | ConvertFrom-Json
$environmentId = $stagingEnvironment.Items[0].Id

Write-Host "The projectId for $EnvironmentName is $environmentId"

$progressionInformation = (Invoke-WebRequest "$OctopusURL/api/$spaceId/progression/$projectId" -Headers $header).content | ConvertFrom-Json
$releaseId = ""

foreach($release in $progressionInformation.Releases)
{        
    foreach ($deployEnv in $release.Deployments)
    {            
        if (Get-Member -InputObject $deployEnv -Name $environmentId -MemberType Properties)
        {
            $releaseId = $release.Release.Id
            break
        }            
    }

    if ([string]::IsNullOrWhiteSpace($releaseId) -eq $false)
    {
        break
    }
}

Write-Host "The most recent release for $ProjectName in the $EnvironmentName Environment is $releaseId"

$bodyRaw = @{
    EnvironmentId = "$environmentId"
    ExcludedMachineIds = @()
    ForcePackageDownload = $False
    ForcePackageRedeployment = $false
    FormValues = @{}
    QueueTime = $null
    QueueTimeExpiry = $null
    ReleaseId = "$releaseId"
    SkipActions = @()
    SpecificMachineIds = @()
    TenantId = $null
    UseGuidedFailure = $false
} 

$bodyAsJson = $bodyRaw | ConvertTo-Json

$redeployment = (Invoke-WebRequest "$OctopusURL/api/$SpaceId/deployments" -Headers $header -Method Post -Body $bodyAsJson -ContentType "application/json").content | ConvertFrom-Json
$taskId = $redeployment.TaskId
$deploymentIsActive = $true

do {
    $deploymentStatus = (Invoke-WebRequest "$OctopusURL/api/tasks/$taskId/details?verbose=false" -Headers $header).content | ConvertFrom-Json
    $deploymentStatusState = $deploymentStatus.Task.State

    if ($deploymentStatusState -eq "Success" -or $deploymentStatusState -eq "Failed"){
        $deploymentIsActive = $false
    }
    else{
        Write-Host "Deployment is still active...checking again in 5 seconds"
        Start-Sleep -Seconds 5
    }

} While ($deploymentIsActive)

Write-Host "Redeployment has finished"