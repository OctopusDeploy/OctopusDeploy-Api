<# This script gathers the following information regarding each project in the specified space on your Octopus instance:

-----------------------------------
Project: <Project name>
Roles used in the project: <roles>
Deployment targets used by the project: <targets>
Tenants connected to the project:
-----------------------------------

It can optionally export the results to a CSV file
#>

# Replace with your actual values
$octopusURL = "https://<OCTOPUS_URL>"
$apiKey = "<API_KEY>"
$spaceName = "<SPACE_NAME>"             # The name of the space you want to query

# Variables for CSV export
$exportToCsv = $true                    # Set to $true to enable CSV export
$exportPath = "C:\<EXPORT>\<PATH>\export.csv"   # Set the desired export path

$header = @{ "X-Octopus-ApiKey" = $apiKey }

# Get the space ID from the space name
$spacesUrl = "$octopusURL/api/spaces/all"
$spaces    = Invoke-RestMethod -Method Get -Uri $spacesUrl -Headers $header
$space     = $spaces | Where-Object { $_.Name -eq $spaceName }

if ($null -eq $space) {
    Write-Host "Space '$spaceName' not found."
    exit
}

$spaceId = $space.Id

# Get all projects in the specified space
$projectsUrl = "$octopusURL/api/$($spaceId)/projects/all"
$projects    = Invoke-RestMethod -Method Get -Uri $projectsUrl -Headers $header

if ($projects.Count -eq 0) {
    Write-Host "No projects found in space '$spaceName'."
    exit
}

# Get all deployment targets in the space
$machinesUrl = "$octopusURL/api/$($spaceId)/machines/all"
$allMachines = Invoke-RestMethod -Method Get -Uri $machinesUrl -Headers $header

# Get all tenants in the space
$tenantsUrl = "$octopusURL/api/$($spaceId)/tenants/all"
$allTenants = Invoke-RestMethod -Method Get -Uri $tenantsUrl -Headers $header

# Initialize an array to collect results
$projectResults = @()

foreach ($project in $projects) {
    Write-Host "-----------------------------------"
    Write-Host "Project: $($project.Name)"

    # Initialize variables for this project
    $projectName = $project.Name
    $projectIsCaC = $false
    $projectIsTenanted = $false
    $roles = @()
    $machinesUsed = @()
    $tenantsConnected = @()

    # Skip project if it is Configuration as Code (CaC)
    if ($project.PersistenceSettings -and $project.PersistenceSettings.Type -eq "VersionControlled") {
        Write-Host " - This project is stored in Git - Unable to determine corresponding targets"
        $projectIsCaC = $true

        # Add a single row for the project
        $projectResults += [PSCustomObject]@{
            ProjectName           = $projectName
            DeploymentTarget      = ''
            Tenant                = ''
        }
        continue
    }

    # Get the deployment process for the project
    $deploymentProcessUrl = "$octopusURL/api/$($spaceId)/deploymentprocesses/$($project.DeploymentProcessId)"
    $deploymentProcess    = Invoke-RestMethod -Method Get -Uri $deploymentProcessUrl -Headers $header

    # Get roles/target tags for each step
    foreach ($step in $deploymentProcess.Steps) {
        if ($null -ne $step.Properties -and $step.Properties.PSObject.Properties.Count -gt 0) {
            $rolePropertyKey = "Octopus.Action.TargetRoles"
            # Retrieve the property value
            if ($step.Properties -is [System.Collections.IDictionary]) {
                $propertyValue = $step.Properties[$rolePropertyKey]
            } else {
                $propertyValue = $step.Properties."$rolePropertyKey"
            }

            if (-not [string]::IsNullOrWhiteSpace($propertyValue)) {
                # Split and collect roles
                $stepRoles = $propertyValue -split ',' | ForEach-Object { $_.Trim() }
                $roles    += $stepRoles
            }
        }

        # Check each action in the step
        if ($step.Actions -ne $null) {
            foreach ($action in $step.Actions) {
                if ($null -ne $action.Properties -and $action.Properties.PSObject.Properties.Count -gt 0) {
                    $rolePropertyKey = "Octopus.Action.TargetRoles"
                    # Retrieve the property value
                    if ($action.Properties -is [System.Collections.IDictionary]) {
                        $propertyValue = $action.Properties[$rolePropertyKey]
                    } else {
                        $propertyValue = $action.Properties."$rolePropertyKey"
                    }

                    if (-not [string]::IsNullOrWhiteSpace($propertyValue)) {
                        $actionRoles = $propertyValue -split ',' | ForEach-Object { $_.Trim() }
                        $roles += $actionRoles
                    }
                }
            }
        }
    }

    # Remove duplicate roles
    $roles = $roles | Select-Object -Unique

    if ($roles.Count -gt 0) {
        Write-Host "Roles used in the project: $($roles -join ', ')"
    } else {
        Write-Host "No roles found for the project."
    }

    # Find deployment targets (machines) that have these roles
    $machinesUsed = $allMachines | Where-Object {
        ($_.Roles | Where-Object { $roles -contains $_ }) -and ($_.IsDisabled -eq $false)
    }

    if ($machinesUsed.Count -gt 0) {
        Write-Host "Deployment targets used by the project:"
        foreach ($machine in $machinesUsed) {
            Write-Host " - $($machine.Name)"
        }
    } else {
        Write-Host "No deployment targets found for the project."
    }

    # Get tenants connected to the project
    if ($project.TenantedDeploymentMode -ne "Untenanted") {
        $projectIsTenanted = $true

        # Filter tenants connected to this project
        $projectTenants = ($allTenants | Where-Object {
            if ($_.ProjectEnvironments -ne $null) {
                # Retrieve the keys from ProjectEnvironments
                $projectEnvironmentKeys = @()
                if ($_.ProjectEnvironments -is [System.Collections.IDictionary]) {
                    $projectEnvironmentKeys = $_.ProjectEnvironments.Keys
                } else {
                    $projectEnvironmentKeys = $_.ProjectEnvironments.PSObject.Properties.Name
                }

                # Check if the project ID is in the keys
                $projectEnvironmentKeys -contains $project.Id
            } else {
                $false
            }
        })

        if ($projectTenants.Count -gt 0) {
            Write-Host "Tenants connected to the project:"
            foreach ($tenant in $projectTenants) {
                Write-Host " - $($tenant.Name)"
            }
            $tenantsConnected = $projectTenants.Name
        } else {
            Write-Host "No tenants connected to the project."
        }
    } else {
        Write-Host "Project is not tenanted."
    }

    # Prepare data for CSV output
    # Create combinations of Deployment Targets and Tenants
    if ($machinesUsed.Count -eq 0) {
        $machinesUsed = @('')
    } else {
        $machinesUsed = $machinesUsed | Select-Object -ExpandProperty Name
    }

    if ($tenantsConnected.Count -eq 0) {
        $tenantsConnected = @('')
    }

    # Create rows for each combination
    foreach ($machineName in $machinesUsed) {
        foreach ($tenantName in $tenantsConnected) {
            $projectResults += [PSCustomObject]@{
                ProjectName      = $projectName
                DeploymentTarget = $machineName
                Tenant           = $tenantName
            }
        }
    }
}

Write-Host "-----------------------------------`n"

# Export results to CSV if enabled
if ($exportToCsv -and $projectResults.Count -gt 0) {
    try {
        $projectResults | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported to CSV file at '$exportPath'"
    } catch {
        Write-Error "Failed to export results to CSV: $_"
    }
}
