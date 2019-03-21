###CONFIG###
$OctopusURL = ## Your URL
$APIKey = ## YOUR API KEY
$SpaceId = $OctopusParameters["Octopus.Space.Id"]
$EnvironmentId = $OctopusParameters["Octopus.Environment.Id"]
$ProjectId = $OctopusParameters["Octopus.Project.Id"]
$DeploymentId = $OctopusParameters["Octopus.Deployment.Id"]
$ChannelId = $OctopusParameters["Octopus.Release.Channel.Id"]

###PROCESS###
$header = @{ "X-Octopus-ApiKey" = $APIKey }

$progressionInformationRaw = (Invoke-WebRequest "$OctopusURL/api/$spaceId/progression/$projectId" -Headers $header).content
$progressionInformation = $progressionInformationRaw | ConvertFrom-Json

# Uncomment this section to see the entire response, it is quite large
# Write-Host "Progression information is a bit hard to wrap our head around, it would be easier to write it out so we can look at it"
# Write-Host $progressionInformationRaw

$releaseId = ""
$releaseForEnvironment = 0

foreach($release in $progressionInformation.Releases)
{            
    $releaseVersion = $release.Release.Version
    Write-Host "Checking $releaseVersion"

    foreach ($deployEnv in $release.Deployments)
    {                   
        if (Get-Member -InputObject $deployEnv -Name $environmentId -MemberType Properties)
        {                    
            Write-Host "$releaseVersion has been deployed to $environmentId, checking the status"
            $deploymentList = $deployEnv.$environmentId 

            # This release has gone to the environment we are interested in, now let's find the most recent release and check the status on that
            $lastDeploymentIndex = $deploymentList.Count - 1
            $lastDeploymentForEnvironment = $deploymentList[$lastDeploymentIndex]

            $lastDeploymentId = $lastDeploymentForEnvironment.DeploymentId
            $lastDeploymentStatus = $lastDeploymentForEnvironment.State
            $lastDeploymentChannel = $release.Channel.Id
            
            Write-Host "The last deployment id for version $releaseVersion is $lastDeploymentId, the status is $lastDeploymentStatus"
                            
            if ($DeploymentId -eq $lastDeploymentId)
            {
                Write-Host "DeploymentId $lastDeploymentId for version $releaseVersion is the current active deployment, skipping"
            }
            elseif($lastDeploymentStatus -ne "Success")
            {
                Write-Host "DeploymentId $lastDeploymentId for version $releaseVersion has a status of $lastDeploymentStatus.  We are only interested in success, skipping"
            }            
            elseif($lastDeploymentChannel -ne $ChannelId)
            {
                Write-Host "DeploymentId $lastDeploymentId for version $releaseVersion was for channel $lastDeploymentChannel, we want $ChannelId, skipping"
            }
            else
            {
                Write-Host "DeploymentId $lastDeploymentId for version $releaseVersion is not the current deployment and has a successful status, using"

                $releaseId = $release.Release.Id
                break
            }                              
        }            
    }

    if ([string]::IsNullOrWhiteSpace($releaseId) -eq $false)
    {
        break
    }
}

if ([string]::IsNullOrWhiteSpace($releaseId) -eq $false)
{
    Write-Host "The last successful release found is $releaseId"

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

    Write-Host "The previous deployment has been successfully triggered"
}
else {
    Write-Host "No previous successful release was found for this environment"
}