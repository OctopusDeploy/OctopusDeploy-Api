# Variables
$octopusUrl = "[YOUR URL]"
$apiKey = "[YOUR API KEY]"
$projectName = "" #example: RandomQuotes-MultiTenant
$releaseVersion = "" #Example: 2018.10.334
$environmentName = "" #Example: Production"
$spaceId = "Spaces-1" ## Leave as Spaces-1 for default space"

# Header
$header = @{ "X-Octopus-ApiKey" = $apiKey }

Write-Host "Get Information about the Project $projectName"
$project = invoke-restmethod "$octopusUrl/$spaceId/projects/randomquotes-multitenant" -Headers $header
$projectId = $project.Id
Write-Host "The Id for $projectName is $projectId"

Write-Host "Get Release Information for version $releaseVersion for $projectName"
$release = Invoke-RestMethod "$octopusUrl/$spaceId/projects/$projectId/releases/$releaseVersion" -Headers $header
$releaseId = $release.Id
$channelId = $release.ChannelId
Write-Host "The Id for the release $releaseVersion for $projectName is $releaseId"
Write-Host "The Channel Id for the release $releaseVersion for $projectName is $channelId"

Write-Host "Getting LifeCycle Id for $channelId"
$channel = Invoke-RestMethod "$octopusUrl/$spaceId/channels/$channelId" -Headers $header
$lifeCycleId = $channel.LifeCycleId
Write-Host "The LifeCycle Id for $channelId is $lifeCycleId"

Write-Host "Getting LifeCycle Details for $lifeCycleId"
$lifeCycle = Invoke-RestMethod "$octopusUrl/$spaceId/lifecycles/$lifeCycleId" -Headers $header
$lifeCycleName = $lifeCycle.Name
Write-Host "The LifeCycle chosen for $releaseVersion for $projectName is $lifeCycleName"

Write-Host "Getting all the environments"
$environmentList = Invoke-RestMethod "$octopusUrl/$spaceId/environments?skip=0&take=10000" -Headers $header
$deployToEnvironment = $environmentList.Items | Where {$_.Name -eq $environmentName}
$deployToEnvironmentId = $deployToEnvironment.Id
Write-Host "The Id of the environment $environmentName is $deployToEnvironmentId"

Write-Host "Getting all the tenants"
$tenantList = Invoke-RestMethod "$octopusUrl/$spaceId/tenants?skip=0&take=100000" -Headers $header
$tenantsFound = $tenantList.TotalResults
Write-Host "Found $tenantsFound, looping through them to see which is associated with $projectName"

$tenantMatchingList = @()
foreach ($tenant in $tenantList.Items)
{
    #The project id is actually a property, so we need to find that
    if (Get-Member -InputObject $tenant.ProjectEnvironments -Name $projectId -MemberType Properties)
    {
        $tenantName = $tenant.Name
        Write-Host "$tenantName is tied to $projectName, adding to list"
        $tenantToAdd = @{
            Name = $tenant.Name
            Id = $tenant.Id
            Environments = $tenant.ProjectEnvironments.$projectId
        }        
        $tenantMatchingList += $tenantToAdd
    }
}

$tenantCount = $tenantMatchingList.Count
Write-Host "Found $tenantCount tenant(s) tied to $projectName"

Write-Host "Getting all the deployments for $releaseVersion for $projectName"
$deploymentList = Invoke-RestMethod "$octopusUrl/$spaceId/releases/$releaseId/deployments?skip=0&take=1000" -Headers $header
$deploymentCount = $deploymentList.TotalResults
Write-Host "Release $releaseVersion for Project $projectName has been deployed $deploymentCount time(s)"

Write-Host "We now have all the information we need to determine if a tenant can be deployed to, calculating"

Write-Host "Determining which environments need to be deployed to in order to deploy to $environmentName"
$requiredPhases = @()
foreach ($phase in $lifeCycle.Phases)
{
    if ($phase.AutomaticDeploymentTargets -contains $deployToEnvironmentId -or $phase.OptionalDeploymentTargets -contains $deployToEnvironmentId)
    {
        $phaseName = $phase.Name
        Write-Host "Phase $phaseName has the target environmentId, exiting loop"
        break
    }

    if ($phase.IsOptionalPhase -eq $false)
    {
        if ($phase.AutomaticDeploymentTargets.Count -gt 0)
        {
            $requiredPhases += $phase.AutomaticDeploymentTargets
        }
        else
        {
            $requiredPhases += $phase.OptionalDeploymentTargets
        }
    }
}
$requiredPhasesCount = $requiredPhases.Count
Write-Host "Found $requiredPhasesCount phase(s) which must be deployed to prior to going to $environmentName"

Write-Host "Looping through the tenants"
$tenantCanDeployList = @()
foreach ($tenant in $tenantMatchingList)
{
    $tenantName = $tenant.Name
    Write-Host "Checking $tenantName"

    $requiredTenantPhases = 0
    $successTenantDeployments = 0
    foreach($phase in $requiredPhases)
    {
        :phaseloop foreach($tenantEnv in $tenant.Environments)
        {
            if ($phase -contains $tenantEnv)
            {                
                Write-Host "$tenantName is tied to $tenantEnv, which means I have to find a successful deployment to that environment before allowing a deployment to $environmentName"
                $requiredTenantPhases += 1


                $envTenantDeploymentList = @($deploymentList.Items | Where {$_.TenantId -eq $tenant.Id -and $_.EnvironmentId -eq $tenantEnv})
                $envTenantDeploymentCount = $envTenantDeploymentList.Count
                Write-Host "Found $envTenantDeploymentCount deployment(s) for $tenantName to $tenantEnv"

                if ($envTenantDeploymentCount -gt 0)
                {                    
                    foreach ($envTenantDeployment in $envTenantDeploymentList)
                    {
                        $deploymentId = $envTenantDeployment.Id
                        Write-Host "Deployment $deploymentId went to $env, ensuring it was successful"                
                        $taskId = $deployment.TaskId
                        $task = Invoke-RestMethod "$octopusUrl/tasks/$taskId" -Headers $header

                        $state = $task.State
                        if ($state -eq "Success")
                        {
                            Write-Host "Deployment $deploymentId was successfully deployed"                            
                            $successTenantDeployments += 1
                            break phaseloop
                        }
                    }
                }                
            }
        }
    }

    if ($requiredTenantPhases -eq $successTenantDeployments)
    {
        $tenantCanDeployList += $tenant
    }
}

Write-Host "The following tenants can be deployed to $environmentName"
foreach ($tenant in $tenantCanDeployList)
{
    Write-Host $tenant.Name
}
