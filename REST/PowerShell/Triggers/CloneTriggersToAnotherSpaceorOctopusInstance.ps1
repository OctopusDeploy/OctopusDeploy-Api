# ======================================================================================
#      Clone Project/Runbook Triggers to a different Space or Octopus Instance
#      This script is designed to run after importing Projects using the Octopus
#      Import/Export Projects tool: https://octopus.com/docs/projects/export-import
# ======================================================================================

$ErrorActionPreference = "Stop";

# Define working variables
$SourceOctopusURL = "http://YOUR_OCTOPUS_URL"
$SourceOctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$SourceHeader = @{ "X-Octopus-ApiKey" = $SourceOctopusAPIKey }
$SourceSpaceId = "Spaces-1"

$DestinationOctopusURL = "http://YOUR_OCTOPUS_URL"
$DestinationOctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$DestinationHeader = @{ "X-Octopus-ApiKey" = $DestinationOctopusAPIKey }
$DestinationSpaceId = "Spaces-2"

# Build Project Id/Project name lists + Tenant Id/Tenant name lists + Environment Id/Environment name lists
$SourceProjects = Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Projects/all" -Headers $SourceHeader
$DestinationProjects = Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Projects/all" -Headers $DestinationHeader

$SourceTenants = Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Tenants/all" -Headers $SourceHeader
$DestinationTenants = Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Tenants/all" -Headers $DestinationHeader

$SourceTenantTags = Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/TagSets/all" -Headers $SourceHeader
$DestinationTenantTags = Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/TagSets/all" -Headers $DestinationHeader

$SourceEnvironments = Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Environments/all" -Headers $SourceHeader
$DestinationEnvironments = Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Environments/all" -Headers $DestinationHeader

# Get Project/Runbook triggers
$SourceTriggersRaw = Invoke-RestMethod -Method Get -Uri "$SourceOctopusURL/api/$($SourceSpaceId)/projecttriggers" -Headers $SourceHeader
$SourceTriggers = $SourceTriggersRaw.items
$DestinationTriggersRaw = Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers" -Headers $DestinationHeader
$DestinationTriggers = $DestinationTriggersRaw.items

$NoMatchingProject = @()
$UnableToCreate = @()

# Find names from ids in $Source___ info above with .ActionType -eq "DeployLatestRelease"
Foreach ($SourceTrigger in ($SourceTriggers | Where-Object { $_.Action.ActionType -eq "DeployLatestRelease" })) {
    $SourceTriggerProject = ($SourceProjects | Where-Object { $_.Id -eq $SourceTrigger.ProjectId })
    $SourceTriggerProjectChannelsListRaw = (Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Projects/$($SourceTriggerProject.Id)/channels" -Headers $SourceHeader)
    $SourceTriggerProjectChannelsList = $SourceTriggerProjectChannelsListRaw.items
    $SourceTriggerChannel = ($SourceTriggerProjectChannelsList | Where-Object { $_.Id -eq $SourceTrigger.Action.ChannelId })
    $SourceTriggerSourceEnvironment = ($SourceEnvironments | Where-Object { $_.Id -eq $SourceTrigger.Action.SourceEnvironmentIds })
    $SourceTriggerDestinationEnvironment = ($SourceEnvironments | Where-Object { $_.Id -eq $SourceTrigger.Action.DestinationEnvironmentId })
    
    $SourceTriggerTenants = @()
    Foreach ($TenantId in $SourceTrigger.Action.TenantIds) {
        $SourceTriggerTenants += ($SourceTenants | Where-Object { $_.Id -eq $TenantId })
    }
    
    $SourceTriggerTenantTags = @()
    Foreach ($TenantTag in $SourceTrigger.Action.TenantTags) {
        $SourceTriggerTenantTags += ($SourceTenantTags | Where-Object { $_.Id -eq $TenantTag })
    }

    # Match $SourceTrigger___ names to Destination info
    $DestinationTriggerProject = ($DestinationProjects | Where-Object { $_.name -eq $SourceTriggerProject.name })
    If (!$DestinationTriggerProject) {
        Write-Warning "The Project `"$($SourceTriggerProject.name)`" was not found in `"$DestinationSpaceId`" of the destination Octopus Server. Skipping..."
        Write-Host "-"
        $NoMatchingProject += $SourceTrigger
    }
    
    If ($DestinationTriggerProject) {
        $DestinationTriggerProjectChannelsListRaw = (Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Projects/$($DestinationTriggerProject.Id)/channels" -Headers $DestinationHeader)
        $DestinationTriggerProjectChannelsList = $DestinationTriggerProjectChannelsListRaw.items
        $DestinationTriggerProjectChannel = ($DestinationTriggerProjectChannelsList | Where-Object { $_.name -eq $SourceTriggerChannel.name })
        $DestinationTriggerSourceEnvironments = ($DestinationEnvironments | Where-Object { $_.name -eq $SourceTriggerSourceEnvironment.name })
        $DestinationTriggerDestinationEnvironment = ($DestinationEnvironments | Where-Object { $_.name -eq $SourceTriggerDestinationEnvironment.name })
        
        $DestinationTriggerTenants = @()
        Foreach ($SourceTriggerTenant in $SourceTriggerTenants) {
            $DestinationTriggerTenants += ($DestinationTenants | Where-Object { $_.name -eq $SourceTriggerTenant.name })
        }
        $DestinationTriggerTenantTags = @()
        Foreach ($SourceTriggerTenantTag in $SourceTriggerTenantTags) {
            $DestinationTriggerTenantTags += ($DestinationTenantTags | Where-Object { $_.name -eq $SourceTriggerTenantTag.name })
        }

        # Convert $SourceTrigger to $DestinationTriggerJSON
        $DestinationTriggerJSON = $SourceTrigger
        $DestinationTriggerJSON.Id = $null
        $DestinationTriggerJSON.Links = $null
        $DestinationTriggerJSON.SpaceId = $DestinationSpaceId
        $DestinationTriggerJSON.name = $SourceTrigger.name
        $DestinationTriggerJSON.ProjectId = $DestinationTriggerProject.Id
        $DestinationTriggerJSON.Action.ChannelId = $DestinationTriggerProjectChannel.Id
        $DestinationTriggerJSON.Action.DestinationEnvironmentId = $DestinationTriggerDestinationEnvironment.Id
        
        $DestinationTriggerJSON.Action.SourceEnvironmentIds = @()
        Foreach ($DestinationTriggerSourceEnvironment in $DestinationTriggerSourceEnvironments) {
            $DestinationTriggerJSON.Action.SourceEnvironmentIds += $DestinationTriggerSourceEnvironment.Id
        }

        $DestinationTriggerJSON.Action.TenantIds = @()
        Foreach ($DestinationTriggerTenant in $DestinationTriggerTenants) {
            $DestinationTriggerJSON.Action.TenantIds += $DestinationTriggerTenant.Id
        }
        
        $DestinationTriggerJSON.Action.TenantTags = @()
        Foreach ($DestinationTriggerTenantTag in $DestinationTriggerTenantTags) {
            $DestinationTriggerJSON.Action.TenantTags += $DestinationTriggerTenantTag.Id
        }

        # Commit $DestinationTriggerJSON to $DestinationOctopusURL
        Try {
            Invoke-RestMethod -Method POST "$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers" -Body ($DestinationTriggerJSON | ConvertTo-Json -Depth 10) -Headers $DestinationHeader
        }

        Catch {
            Write-Warning "Unable to create trigger via POST to `"$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers`"."
            Write-Warning "Trigger `"$($SourceTrigger.name)`" may already exist or the API KEY may not have permission to create a trigger for Project `"$($DestinationTriggerProject.name)`""
            Write-Host "-"
            $UnableToCreate += $SourceTrigger
        }
    }
}

# Find names from ids in $Source___ info above with .ActionType -eq "DeployNewRelease"
Foreach ($SourceTrigger in ($SourceTriggers | Where-Object { $_.Action.ActionType -eq "DeployNewRelease" })) {
    $SourceTriggerProject = ($SourceProjects | Where-Object { $_.Id -eq $SourceTrigger.ProjectId })
    $SourceTriggerProjectChannelsListRaw = (Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Projects/$($SourceTriggerProject.Id)/channels" -Headers $SourceHeader)
    $SourceTriggerProjectChannelsList = $SourceTriggerProjectChannelsListRaw.items
    $SourceTriggerChannel = ($SourceTriggerProjectChannelsList | Where-Object { $_.Id -eq $SourceTrigger.Action.ChannelId })
    $SourceTriggerEnvironment = ($SourceEnvironments | Where-Object { $_.Id -eq $SourceTrigger.Action.EnvironmentId })
	
    $SourceTriggerTenants = @()
    Foreach ($TenantId in $SourceTrigger.Action.TenantIds) {
        $SourceTriggerTenants += ($SourceTenants | Where-Object { $_.Id -eq $TenantId })
    }
	
    $SourceTriggerTenantTags = @()
    Foreach ($TenantTag in $SourceTrigger.Action.TenantTags) {
        $SourceTriggerTenantTags += ($SourceTenantTags | Where-Object { $_.Id -eq $TenantTag })
    }

    # Match $SourceTrigger___ names to Destination info
    $DestinationTriggerProject = ($DestinationProjects | Where-Object { $_.name -eq $SourceTriggerProject.name })
    If (!$DestinationTriggerProject) {
        Write-Warning "The Project `"$($SourceTriggerProject.name)`" was not found in `"$DestinationSpaceId`" of the destination Octopus Server. Skipping..."
        Write-Host "-"
        $NoMatchingProject += $SourceTrigger
    }
    
    If ($DestinationTriggerProject) {
        $DestinationTriggerProjectChannelsListRaw = (Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Projects/$($DestinationTriggerProject.Id)/channels" -Headers $DestinationHeader)
        $DestinationTriggerProjectChannelsList = $DestinationTriggerProjectChannelsListRaw.items
        $DestinationTriggerProjectChannel = ($DestinationTriggerProjectChannelsList | Where-Object { $_.name -eq $SourceTriggerChannel.name })
        $DestinationTriggerEnvironment = ($DestinationEnvironments | Where-Object { $_.name -eq $SourceTriggerEnvironment.name })
		
        $DestinationTriggerTenants = @()
        Foreach ($SourceTriggerTenant in $SourceTriggerTenants) {
            $DestinationTriggerTenants += ($DestinationTenants | Where-Object { $_.name -eq $SourceTriggerTenant.name })
        }
		
        $DestinationTriggerTenantTags = @()
        Foreach ($SourceTriggerTenantTag in $SourceTriggerTenantTags) {
            $DestinationTriggerTenantTags += ($DestinationTenantTags | Where-Object { $_.name -eq $SourceTriggerTenantTag.name })
        }

        # Convert $SourceTrigger to $DestinationTriggerJSON
        $DestinationTriggerJSON = $SourceTrigger
        $DestinationTriggerJSON.Id = $null
        $DestinationTriggerJSON.Links = $null
        $DestinationTriggerJSON.SpaceId = $DestinationSpaceId
        $DestinationTriggerJSON.name = $SourceTrigger.name
        $DestinationTriggerJSON.ProjectId = $DestinationTriggerProject.Id
        $DestinationTriggerJSON.Action.ChannelId = $DestinationTriggerProjectChannel.Id
        $DestinationTriggerJSON.Action.EnvironmentId = $DestinationTriggerEnvironment.Id

        $DestinationTriggerJSON.Action.TenantIds = @()
        Foreach ($DestinationTriggerTenant in $DestinationTriggerTenants) {
            $DestinationTriggerJSON.Action.TenantIds += $DestinationTriggerTenant.Id
        }
        
        $DestinationTriggerJSON.Action.TenantTags = @()
        Foreach ($DestinationTriggerTenantTag in $DestinationTriggerTenantTags) {
            $DestinationTriggerJSON.Action.TenantTags += $DestinationTriggerTenantTag.Id
        }

        # Commit $DestinationTriggerJSON to $DestinationOctopusURL
        Try {
            Invoke-RestMethod -Method POST "$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers" -Body ($DestinationTriggerJSON | ConvertTo-Json -Depth 10) -Headers $DestinationHeader
        }

        Catch {
            Write-Warning "Unable to create trigger via POST to `"$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers`"."
            Write-Warning "Trigger `"$($SourceTrigger.name)`" may already exist or the API KEY may not have permission to create a trigger for Project `"$($DestinationTriggerProject.name)`""
            Write-Host "-"
            $UnableToCreate += $SourceTrigger
        }
    }
}

# Find names from ids in $Source___ info above with .ActionType -eq "AutoDeploy"
Foreach ($SourceTrigger in ($SourceTriggers | Where-Object { $_.Action.ActionType -eq "AutoDeploy" })) {
    $SourceTriggerProject = ($SourceProjects | Where-Object { $_.Id -eq $SourceTrigger.ProjectId })
    $SourceTriggerEnvironments = ($SourceEnvironments | Where-Object { $_.Id -eq $SourceTrigger.Filter.EnvironmentIds })

    # Match $SourceTrigger___ names to Destination info
    $DestinationTriggerProject = ($DestinationProjects | Where-Object { $_.name -eq $SourceTriggerProject.name })
    If (!$DestinationTriggerProject) {
        Write-Warning "The Project `"$($SourceTriggerProject.name)`" was not found in `"$DestinationSpaceId`" of the destination Octopus Server. Skipping..."
        Write-Host "-"
        $NoMatchingProject += $SourceTrigger
    }
	
    If ($DestinationTriggerProject) {
        $DestinationTriggerEnvironments = ($DestinationEnvironments | Where-Object { $_.name -eq $SourceTriggerEnvironments.name })

        # Convert $SourceTrigger to $DestinationTriggerJSON
        $DestinationTriggerJSON = $SourceTrigger
        $DestinationTriggerJSON.Id = $null
        $DestinationTriggerJSON.Links = $null
        $DestinationTriggerJSON.SpaceId = $DestinationSpaceId
        $DestinationTriggerJSON.name = $SourceTrigger.name
        $DestinationTriggerJSON.ProjectId = $DestinationTriggerProject.Id
        
        $DestinationTriggerJSON.Filter.EnvironmentIds = @()
		Foreach ($DestinationTriggerEnvironment in $DestinationTriggerEnvironments) {
		    $DestinationTriggerJSON.Filter.EnvironmentIds += $DestinationTriggerEnvironments.Id
		}

        # Commit $DestinationTriggerJSON to $DestinationOctopusURL
        Try {
            Invoke-RestMethod -Method POST "$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers" -Body ($DestinationTriggerJSON | ConvertTo-Json -Depth 10) -Headers $DestinationHeader
        }

        Catch {
            Write-Warning "Unable to create trigger via POST to `"$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers`"."
            Write-Warning "Trigger `"$($SourceTrigger.name)`" may already exist or the API KEY may not have permission to create a trigger for Project `"$($DestinationTriggerProject.name)`""
            Write-Host "-"
            $UnableToCreate += $SourceTrigger
        }
    }
}

# Find names from ids in $Source___ info above with .ActionType -eq "RunRunbook"
Foreach ($SourceTrigger in ($SourceTriggers | Where-Object { $_.Action.ActionType -eq "RunRunbook" })) {
    $SourceTriggerProject = ($SourceProjects | Where-Object { $_.Id -eq $SourceTrigger.ProjectId })
    $SourceTriggerProjectRunbooksList = (Invoke-RestMethod -Method GET "$SourceOctopusURL/api/$($SourceSpaceId)/Projects/$($SourceTriggerProject.Id)/runbooks/all" -Headers $SourceHeader)
    $SourceTriggerRunbook = ($SourceTriggerProjectRunbooksList | Where-Object { $_.Id -eq $SourceTrigger.Action.RunbookId })
    $SourceTriggerEnvironments = ($SourceEnvironments | Where-Object { $_.Id -eq $SourceTrigger.Action.EnvironmentIds })
    
	$SourceTriggerTenants = @()
    Foreach ($TenantId in $SourceTrigger.Action.TenantIds) {
        $SourceTriggerTenants += ($SourceTenants | Where-Object { $_.Id -eq $TenantId })
    }
	
    $SourceTriggerTenantTags = @()
    Foreach ($TenantTag in $SourceTrigger.Action.TenantTags) {
        $SourceTriggerTenantTags += ($SourceTenantTags | Where-Object { $_.Id -eq $TenantTag })
    }
	

    # Match $SourceTrigger___ names to Destination info
    $DestinationTriggerProject = ($DestinationProjects | Where-Object { $_.name -eq $SourceTriggerProject.name })
    If (!$DestinationTriggerProject) {
        Write-Warning "The Project `"$($SourceTriggerProject.name)`" was not found in `"$DestinationSpaceId`" of the destination Octopus Server. Skipping..."
        Write-Host "-"
        $NoMatchingProject += $SourceTrigger
    }
	
    If ($DestinationTriggerProject) {
        $DestinationTriggerProjectRunbooksList = (Invoke-RestMethod -Method GET "$DestinationOctopusURL/api/$($DestinationSpaceId)/Projects/$($DestinationTriggerProject.Id)/runbooks/all" -Headers $DestinationHeader)
        $DestinationTriggerProjectRunbooks = ($DestinationTriggerProjectRunbooksList | Where-Object { $_.name -eq $SourceTriggerRunbook.name })
        $DestinationTriggerEnvironments = ($DestinationEnvironments | Where-Object { $_.name -eq $SourceTriggerEnvironments.name })
        
		$DestinationTriggerTenants = @()
        Foreach ($SourceTriggerTenant in $SourceTriggerTenants) {
            $DestinationTriggerTenants += ($DestinationTenants | Where-Object { $_.name -eq $SourceTriggerTenant.name })
        }
		
        $DestinationTriggerTenantTags = @()
        Foreach ($SourceTriggerTenantTag in $SourceTriggerTenantTags) {
            $DestinationTriggerTenantTags += ($DestinationTenantTags | Where-Object { $_.name -eq $SourceTriggerTenantTag.name })
        }
				
        $DestinationTriggerJSON = $SourceTrigger
        $DestinationTriggerJSON.Id = $null
        $DestinationTriggerJSON.Links = $null
        $DestinationTriggerJSON.SpaceId = $DestinationSpaceId
        $DestinationTriggerJSON.name = $SourceTrigger.name
        $DestinationTriggerJSON.ProjectId = $DestinationTriggerProject.Id
        $DestinationTriggerJSON.Action.RunbookId = $DestinationTriggerProjectRunbooks.Id
        
        $DestinationTriggerJSON.Action.EnvironmentIds = @()
        Foreach ($DestinationTriggerEnvironment in $DestinationTriggerEnvironments) {
            $DestinationTriggerJSON.Action.EnvironmentIds += $DestinationTriggerEnvironment.Id
        }

        $DestinationTriggerJSON.Action.TenantIds = @()
        Foreach ($DestinationTriggerTenant in $DestinationTriggerTenants) {
            $DestinationTriggerJSON.Action.TenantIds += $DestinationTriggerTenant.Id
        }
        
        $DestinationTriggerJSON.Action.TenantTags = @()
        Foreach ($DestinationTriggerTenantTag in $DestinationTriggerTenantTags) {
            $DestinationTriggerJSON.Action.TenantTags += $DestinationTriggerTenantTag.Id
        }

        # Commit $DestinationTriggerJSON to $DestinationOctopusURL
        Try {
            Invoke-RestMethod -Method POST "$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers" -Body ($DestinationTriggerJSON | ConvertTo-Json -Depth 10) -Headers $DestinationHeader
        }

        Catch {
            Write-Warning "Unable to create trigger via POST to `"$DestinationOctopusURL/api/$($DestinationSpaceId)/projecttriggers`"."
            Write-Warning "Trigger `"$($SourceTrigger.name)`" may already exist or the API KEY may not have permission to create a trigger for Project `"$($DestinationTriggerProject.name)`""
            Write-Host "-"
            $UnableToCreate += $SourceTrigger
        }
    }
}

If ($NoMatchingProject) {
    Write-Warning "No matching destination Projects were found in $DestinationSpaceId at $DestinationOctopusURL for the following source Triggers:"
    Foreach ($_ in $NoMatchingProject) {
        Write-Host "$($_.Name) ($($_.Id)) via $($_.ProjectId)"
    }
    Write-Host ""
}

If ($UnableToCreate) {
    Write-Warning "Unable to create destination Triggers in $DestinationSpaceId at $DestinationOctopusURL for the following source Triggers:"
    Foreach ($_ in $UnableToCreate) {
        Write-Host "$($_.Name) ($($_.Id)) via $($_.ProjectId)"
    }
}
