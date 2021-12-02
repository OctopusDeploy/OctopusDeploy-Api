$OctopusURL = "YOUR URL" #example: https://samples.octopus.app
$SpaceName = "YOUR SPACE NAME" 
$APIKey = "YOUR API KEY"
$header = @{ "X-Octopus-ApiKey" = $APIKey }

$spaceResults = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/spaces" -Headers $header
$spaceToUse = $null

foreach ($space in $spaceResults.Items)
{
    if ($space.Name -eq $SpaceName)
    {
        $spaceToUse = $space        
        break
    }
}

$spaceId = $space.Id
Write-Host "The space-id for $spaceName is $spaceId"

Write-Host "Getting all environments"
$environments = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/environments?skip=0&take=100000" -Headers $header

Write-Host "Getting all tenants"
$tenants = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/tenants?skip=0&take=100000" -Headers $header

Write-Host "Getting all projects"
$projects = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/projects?skip=0&take=100000" -Headers $header
$channels = @{}
$projectVariables = @{}
$deploymentProcess = @{}
$projectTriggers = @{}

Write-Host "Getting all runbooks"
$runbooks = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/runbooks?skip=0&take=100000" -Headers $header

Write-Host "Getting all library variable sets"
$libraryVariableSets = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/libraryvariablesets?skip=0&take=100000" -Headers $header
$libraryVariableSetVariables = @{}

Write-Host "Getting all machines"
$machines = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/machines?skip=0&take=100000" -Headers $header

Write-Host "Getting all lifecycles"
$lifecycles = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/lifecycles?skip=0&take=100000" -Headers $header

Write-Host "Getting all accounts"
$accounts = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/accounts?skip=0&take=100000" -Headers $header

Write-Host "Getting all certificates"
$certs = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/certificates?skip=0&take=100000" -Headers $header

Write-Host "Getting all subscriptions"
$subscriptions = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/subscriptions?skip=0&take=100000" -Headers $header

Write-Host "Getting all teams"
$teams = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/teams?skip=0&take=100000" -Headers $header
$scopedUserRoles = @{}

$environmentsNotUsed = @()
$tenantsNotUsed = @()

Write-Host "Looping through all environments to find it's usage"
foreach ($environment in $environments.Items)
{
    $environmentIsUsed = $false
    Write-Host "Environment: $($environment.Name)"
    
    Write-Host "     Library Variable Set Usage:"
    foreach ($libraryVariableSet in $libraryVariableSets.Items)
    {        
        $variableSetId = $($libraryVariableSet.Id)        
        if ($libraryVariableSetVariables[$variableSetId] -eq $null)
        {            
            $libraryVariableSetVariablesValues = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/variables/variableset-$variableSetId" -Headers $header
            $libraryVariableSetVariables.$($libraryVariableSet.Id) = $libraryVariableSetVariablesValues
        }

        $variables = $libraryVariableSetVariables[$($libraryVariableSet.Id)]

        foreach ($variable in $variables.Variables)
        {            
            if (Get-Member -InputObject $variable.Scope -Name "Environment" -MemberType Properties)
            {                      
                if (@($variable.Scope.Environment) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "          Used in the variable $($variable.Name) in the library set $($libraryVariableSet.Name)"
                }
            }
        }
    }

    Write-Host "     Project Usage:"
    foreach ($project in $projects.Items)
    {                
        if ($channels[$($project.Id)] -eq $null)
        {
            $projectChannels = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/projects/$($project.Id)/channels?skip=0&take=10000" -Headers $header
            $channels.$($project.Id) = $projectChannels
        }

        $channelsToQuery = $channels.$($project.Id)
        
        foreach ($channel in $channelsToQuery.Items)
        {
            $lifecycleId = $channel.LifecycleId
            if ($null -eq $lifecycleId)
            {
                $lifecycleId = $project.LifecycleId
            }

            $lifecycle = $lifecycles.Items | Where-Object {$_.Id -eq $lifecycleId}
            foreach ($phase in $lifecycle.Phases)
            {
                if (@($phase.AutomaticDeploymentTargets) -contains $($environment.Id) -or @($phase.OptionalDeploymentTargets) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "          Used in the phase $($phase.Name) in the lifecycle $($lifecycle.Name) referenced by the project $($project.Name) in the channel $($channel.Name)"
                }
            }            
        }

        if ($projectVariables[$($project.Id)] -eq $null)
        {            
            $projectVariableValues = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/variables/variableSet-$($project.Id)" -Headers $header
            $projectVariables.$($project.Id) = $projectVariableValues
        }

        $variables = $projectVariables[$($project.Id)]

        foreach ($variable in $variables.Variables)
        {            
            if (Get-Member -InputObject $variable.Scope -Name "Environment" -MemberType Properties)
            {                      
                if (@($variable.Scope.Environment) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "          Used in the variable $($variable.Name) in the project variable set for $($project.Name)"
                }
            }
        }

        if ($deploymentProcess[$($project.Id)] -eq $null)
        {            
            $projectDeploymentProcess = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/deploymentprocesses/deploymentprocess-$($project.Id)" -Headers $header
            $deploymentProcess.$($project.Id) = $projectDeploymentProcess
        }

        $deploymentProcessToCheck = $deploymentProcess[$($project.Id)]

        foreach ($step in $deploymentProcessToCheck.Steps)
        {            
            foreach ($action in $step.Actions)
            {
                if (@($action.Environments) -contains $($environment.Id) -or @($action.ExcludedEnvironments) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "          Used in the step $($action.Name) in the deployment process for $($project.Name)"
                }
            }                     
                            
        }

        if ($projectTriggers[$($project.Id)] -eq $null)
        {            
            $projectTriggerResult = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/projects/$($project.Id)/triggers?skip=0&take=10000" -Headers $header
            $projectTriggers.$($project.Id) = $projectTriggerResult
        }

        $projectTriggersToCheck = $projectTriggers[$($project.Id)]

        foreach ($trigger in $projectTriggersToCheck.Items)
        {               
            if (@($trigger.Action.EnvironmentId) -eq $($environment.Id))
            {
                $environmentIsUsed = $true
                Write-Host "          Used in the trigger $($trigger.Name) for $($project.Name)"
            }                                                                     
        }

        foreach ($tenant in $tenants.Items)
        {
            
            if (Get-Member -InputObject $tenant.ProjectEnvironments -Name $($project.Id) -MemberType Properties)
            {
                if (@($tenant.ProjectEnvironments.$($project.Id)) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "          Referenced by tenant $($tenant.Name) for $($project.Name)"
                }
            }
        }
    }

    Write-Host "     Runbook Usage:"
    foreach ($runbook in $runbooks.Items)
    {
        if (Get-Member -InputObject $runbook -Name "Environments" -MemberType Properties)
        {                      
            if (@($runbook.Environments) -contains $($environment.Id))
            {
                $environmentIsUsed = $true
                Write-Host "         Referenced by runbook $($runbook.Name) in the settings"
            }
        }

        
        if ($deploymentProcess[$($runbook.Id)] -eq $null)
        {                        
            $projectDeploymentProcess = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/runbookProcesses/RunbookProcess-$($runbook.Id)" -Headers $header
            $deploymentProcess.$($runbook.Id) = $projectDeploymentProcess
        }

        $deploymentProcessToCheck = $deploymentProcess[$($runbook.Id)]

        foreach ($step in $deploymentProcessToCheck.Steps)
        {            
            foreach ($action in $step.Actions)
            {
                if (@($action.Environments) -contains $($environment.Id) -or @($action.ExcludedEnvironments) -contains $($environment.Id))
                {
                    $environmentIsUsed = $true
                    Write-Host "         Used in the step $($action.Name) in the deployment process for the runbook $($runbook.Name)"
                }
            }                     
                            
        }
    }

    Write-Host "     Machine Usage:"
    foreach ($machine in $machines.Items)
    {
        if (@($machine.EnvironmentIds) -contains $($environment.Id))
        {
            $environmentIsUsed = $true
            Write-Host "         Referenced by machine $($machine.Name)"
        }
    }

    Write-Host "     Account Usage:"
    foreach ($account in $accounts.Items)
    {
        if (@($account.EnvironmentIds) -contains $($environment.Id))
        {
            $environmentIsUsed = $true
            Write-Host "         Referenced by account $($account.Name)"
        }
    }

    Write-Host "     Certificate Usage:"
    foreach ($cert in $certs.Items)
    {
        if (@($certs.EnvironmentIds) -contains $($environment.Id))
        {
            $environmentIsUsed = $true
            Write-Host "         Referenced by certificate $($cert.Name)"
        }
    }

    Write-Host "     Subscription Usage:"
    foreach ($subscription in $subscriptions.Items)
    {
        if (@($subscription.EventNotificationSubscription.Filter.Environments) -contains $($environment.Id))
        {
            $environmentIsUsed = $true
            Write-Host "         Referenced by subscription $($subscription.Name)"
        }
    }

    Write-Host "     Team Usage:"
    foreach ($team in $teams.Items)
    {
        if ($scopedUserRoles[$($team.Id)] -eq $null)
        {                        
            $teamScopedUserRoles = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/teams/$($team.Id)/scopeduserroles?skip=0&take=10000" -Headers $header
            $scopedUserRoles.$($team.Id) = $teamScopedUserRoles
        }

        $scopedRolesToCheck = $scopedUserRoles[$($team.Id)]

        foreach ($userRoles in $scopedRolesToCheck.Items)
        {                                                
            if (@($userRoles.EnvironmentIds) -contains $($environment.Id))
            {
                $environmentIsUsed = $true
                Write-Host "         Used in the team $($team.Name)"
            }                                                             
        }
    }

    $deployments = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/deployments?environments=$($environment.Id)" -Headers $header
    if ($deployments.Items.Count -gt 0)
    {
        $environmentIsUsed = $true
        Write-Host "     Used in $($deployments.TotalResults) deployments"
    }
    else
    {
        Write-Host "     Not used in any deployments"
    }      

    if ($environmentIsUsed -eq $false)
    {
        $environmentsNotUsed += $environment.Name
    }                
}

Write-Host "Looping through all tenants to find it's usage"
foreach ($tenant in $tenants.Items)
{
    $tenantIsUsed = $false

    Write-Host "Tenant: $($Tenant.Name)"
    Write-Host "     Project Usage:"
    $tenant.ProjectEnvironments.PSObject.Properties | ForEach-Object {
        foreach ($project in $projects.Items)
        {
            if ($project.Id -eq $_.Name)
            {
                $tenantIsUsed = $true
                Write-Host "         Tied to project $($project.Name)"
            }
        }
    }

    Write-Host "     Machine Usage:"
    foreach ($machine in $machines.Items)
    {
        if (@($machine.TenantIds) -contains $($tenant.Id))
        {
            $tenantIsUsed = $true
            Write-Host "         Referenced by machine $($machine.Name)"
        }
    }

    Write-Host "     Subscription Usage:"
    foreach ($subscription in $subscriptions.Items)
    {
        if (@($subscription.EventNotificationSubscription.Filter.Tenants) -contains $($tenant.Id))
        {
            $tenantIsUsed = $true
            Write-Host "         Referenced by subscription $($subscription.Name)"
        }
    }

    Write-Host "     Account Usage:"
    foreach ($account in $accounts.Items)
    {
        if (@($account.TenantIds) -contains $($tenant.Id))
        {
            $tenantIsUsed = $true
            Write-Host "         Referenced by account $($account.Name)"
        }
    }

    Write-Host "     Certificate Usage:"
    foreach ($cert in $certs.Items)
    {
        if (@($certs.TenantIds) -contains $($environment.Id))
        {
            $tenantIsUsed = $true
            Write-Host "         Referenced by certificate $($cert.Name)"
        }
    }

    Write-Host "     Team Usage:"
    foreach ($team in $teams.Items)
    {
        if ($scopedUserRoles[$($team.Id)] -eq $null)
        {                        
            $teamScopedUserRoles = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/teams/$($team.Id)/scopeduserroles?skip=0&take=10000" -Headers $header
            $scopedUserRoles.$($team.Id) = $teamScopedUserRoles
        }

        $scopedRolesToCheck = $scopedUserRoles[$($team.Id)]

        foreach ($userRoles in $scopedRolesToCheck.Items)
        {                                                
            if (@($userRoles.TenantIds) -contains $($tenant.Id))
            {
                $tenantIsUsed = $true
                Write-Host "         Used in the team $($team.Name)"
            }                                                             
        }
    } 

    $deployments = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/deployments?tenants=$($tenant.Id)" -Headers $header
    if ($deployments.Items.Count -gt 0)
    {
        $tenantIsUsed = $true
        Write-Host "     Used in $($deployments.TotalResults) deployments"
    }
    else
    {
        Write-Host "     Not used in any deployments"
    }        

    if ($tenantIsUsed -eq $false)
    {
        $tenantsNotUsed += $Tenant.Name
    }       
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Environments Not Used:"
Foreach ($environment in $environmentsNotUsed)
{
    Write-Host "    $environment"
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Tenants Not Used:"
Foreach ($tenant in $tenantsNotUsed)
{
    Write-Host "    $tenant"
}
