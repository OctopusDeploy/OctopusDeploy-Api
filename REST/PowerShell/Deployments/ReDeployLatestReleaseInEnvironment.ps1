###CONFIG###
$OctopusURL = #Your Octopus URL 
$APIKey = #API Key of someone with permissions to redeploy
$SpaceId = #Current SpaceId of the deployment 
$ProjectName = #The Name of the project to look for
$EnvironmentName = #The name of the environment to redeploy to

###PROCESS###
$header = @{ "X-Octopus-ApiKey" = $APIKey }

##GetProjectId
$project = Invoke-RestMethod "$OctopusURL/api/$spaceId/projects?name=$([System.Web.HTTPUtility]::UrlEncode($projectName))&skip=0&take=1" -Headers $header
$projectId = $project.Items[0].Id

Write-Host "The projectId for $ProjectName is $projectId"

$stagingEnvironment = Invoke-RestMethod "$OctopusURL/api/$spaceId/environments?name=$([System.Web.HTTPUtility]::UrlEncode($EnvironmentName))&skip=0&take=1" -Headers $header
$environmentId = $stagingEnvironment.Items[0].Id

Write-Host "The projectId for $EnvironmentName is $environmentId"

$progressionInformation = Invoke-RestMethod "$OctopusURL/api/$spaceId/progression/$projectId" -Headers $header
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

$redeployment = Invoke-RestMethod "$OctopusURL/api/$SpaceId/deployments" -Headers $header -Method Post -Body $bodyAsJson -ContentType "application/json"
$taskId = $redeployment.TaskId
$deploymentIsActive = $true

do {
    $deploymentStatus = Invoke-RestMethod "$OctopusURL/api/tasks/$taskId/details?verbose=false" -Headers $header
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