$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

$deploymentsFrom = "2021-12-02"
$deploymentsTo = "2021-12-05"

# Optional project filter
$projectName = ""

# Optional environment filter
$environmentName = ""

$csvExportPath = "" # path:\to\variable.csv

# Get space
Write-Output "Retrieving space '$($spaceName)'"
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# cache resources as they are retrieved
$releases = @()
$deployments = @()
$deploymentProcesses = @()
$manifestVariableSets = @()
$packages = @()

# Cache all environments
Write-Output "Retrieving all environments"
$environments = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/environments" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $environments += $response.Items
} while ($response.Links.'Page.Next')

# Cache all tenants
Write-Output "Retrieving all tenants"
$tenants = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/tenants" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $tenants += $response.Items
} while ($response.Links.'Page.Next')

# Cache all machines
Write-Output "Retrieving all machines"
$machines = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/machines" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $machines += $response.Items
} while ($response.Links.'Page.Next')

# Cache all projects
Write-Output "Retrieving all projects"
$projects = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projects" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $projects += $response.Items
} while ($response.Links.'Page.Next')

# Return the cached release or retrieve it, cache it and then return it.
function Get-Release {
    param($releaseId)
    
    $release = @($releases | Where-Object { $_.Id -ieq $releaseId }) | Select-Object -First 1
    if ($null -ieq $release) {
        $release = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/releases/$($releaseId)" -Headers $header 
        $releases += $release
    }
    
    return $release
}

function Get-Deployment {
    param($deploymentId)
    
    $deployment = @($deployments | Where-Object { $_.Id -ieq $deploymentId }) | Select-Object -First 1
    if ($null -ieq $deployment) {
        $deployment = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/deployments/$($deploymentId)" -Headers $header 
        $deployments += $deployment
    }
    
    return $deployment
}

function Get-DeploymentProcess {
    param($DeploymentProcessId)
    
    $deploymentProcess = @($deploymentProcesses | Where-Object { $_.Id -ieq $DeploymentProcessId }) | Select-Object -First 1
    if ($null -ieq $deploymentProcess) {
        $deploymentProcess = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($DeploymentProcessId)" -Headers $header 
        $deploymentProcesses += $deploymentProcess
    }
    
    return $deploymentProcess
}

function Get-DeploymentVariables {
    param($ManifestVariableSetId)
    
    $variables = @($manifestVariableSets | Where-Object { $_.Id -ieq $ManifestVariableSetId }) | Select-Object -First 1
    if ($null -ieq $variables) {
        $variables = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/variables/$($ManifestVariableSetId)" -Headers $header 
        $manifestVariableSets += $variables
    }
    
    return $variables
}
function Get-PackageDetails {
    param(
        $PackageId, 
        $PackageVersion
    )
    $Id = "packages-$($PackageId).$PackageVersion"
    $packageDetails = @($packages | Where-Object { $_.Id -ieq $Id }) | Select-Object -First 1
    if ($null -ieq $packageDetails) {
        $packageDetails = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/packages/$($Id)" -Headers $header 
        $packages += $packageDetails
    }
    
    return $packageDetails
}

$eventsUrl = "$octopusURL/api/events?includeSystem=false&spaces=$($space.Id)&eventCategories=DeploymentStarted&documentTypes=Deployments&from=$($deploymentsFrom)T00%3A00%3A00%2B00%3A00&to=$($deploymentsTo)T23%3A59%3A59%2B00%3A00"

# Check for optional project filter
if (-not [string]::IsNullOrWhitespace($projectName)) {
    Write-Verbose "Filtering events to single project '$($projectName)'"
    $project = @($projects | Where-Object { $_.Name -ieq $projectName }) | Select-Object -First 1
    $eventsUrl += "&projects=$($project.Id)"
}
# Check for optional environment filter
if (-not [string]::IsNullOrWhitespace($environmentName)) {
    Write-Verbose "Filtering events to single environment '$($environmentName)'"
    $environment = @($environments | Where-Object { $_.Name -ieq $environmentName }) | Select-Object -First 1
    $eventsUrl += "&environments=$($environment.Id)"
}

# Get events
Write-Output "Retrieving deployment events from '$($deploymentsFrom)' to '$($deploymentsTo)'"
$events = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { $eventsUrl }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $events += $response.Items
} while ($response.Links.'Page.Next')

# TEMP FILTER FOR EVENTS
$events = $events | Where-Object { [int]($_.Id -Replace "Events-", "") -gt 94606 -and [int]($_.Id -Replace "Events-", "") -ne 94621 }

$results = @()

foreach ($event in $events) {
    Write-Verbose "Working on event $($event.Id)"
    # Get related document Ids
    $releaseId = $event.RelatedDocumentIds | Where-Object { $_ -like "Releases-*" } | Select-Object -First 1
    $projectId = $event.RelatedDocumentIds | Where-Object { $_ -like "Projects*" } | Select-Object -First 1
    $deploymentId = $event.RelatedDocumentIds | Where-Object { $_ -like "Deployments*" } | Select-Object -First 1
    $environmentId = $event.RelatedDocumentIds | Where-Object { $_ -like "Environments*" } | Select-Object -First 1
    $taskId = $event.RelatedDocumentIds | Where-Object { $_ -like "ServerTasks*" } | Select-Object -First 1
    
    # Get objects
    $project = $projects | Where-Object { $_.Id -ieq $projectId }
    $release = Get-Release -ReleaseId $releaseId 
    $deployment = Get-Deployment -DeploymentId $deploymentId
    $deploymentProcess = Get-DeploymentProcess -DeploymentProcessId $($deployment.DeploymentProcessId)
    $deploymentVariables = Get-DeploymentVariables -ManifestVariableSetId $($deployment.ManifestVariableSetId)
    $task = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/tasks/$($taskId)" -Headers $header 
    $environment = $environments | Where-Object { $_.Id -ieq $environmentId } 
    $releasePackages = $release.SelectedPackages

    $tenantName = ""

    if (-not [string]::IsNullOrWhitespace($deployment.TenantId)) {
        $tenantName = ($tenants | Where-Object { $_.Id -ieq $deployment.TenantId }).Name
    }
    $deployedToMachines = $deployment.DeployedToMachineIds
    
    foreach ($package in $releasePackages) {
                
        $step = $deploymentProcess.Steps | Where-Object { $_.Name -ieq $package.StepName }    

        if (-not "$($step.Properties)") {
            # No properties
            continue;
        }
        
        $stepAction = ($step.Actions | Select-Object -First 1)
        $packageVersion = $package.Version
        if (-not [string]::IsNullOrWhitespace($package.PackageReferenceName)) {
            $actionPackage = $stepAction.Packages | Where-Object { $_.Name -ieq $package.PackageReferenceName } | Select-Object -First 1
            $packageId = $actionPackage.PackageId
        }
        else {
            $actionPackage = $stepAction.Packages | Where-Object { $_.Name -ieq "" } | Select-Object -First 1
            $packageId = $actionPackage.PackageId
        }

        # Get package details
        $packageDetails = Get-PackageDetails -PackageId $packageId -PackageVersion $packageVersion
        
        $targetMachinesForPackage = @()

        # get target role for package 
        if (-not [string]::IsNullOrWhitespace($step.Properties.'Octopus.Action.TargetRoles')) {
            $packageTargetRoles = ($step.Properties.'Octopus.Action.TargetRoles' -Split ",").Trim()
            foreach ($role in $packageTargetRoles) {
                # Get machines in role 
                $machinesInRole = (($deploymentVariables.Variables | Where-Object { $_.Name -ieq "Octopus.Environment.MachinesInRole[$($role)]" }).Value -Split ",").Trim()
                foreach ($machineId in $machinesInRole) {
                    if ($machineId -in $deployedToMachines) {
                        $machineName = ($machines | Where-Object { $_.Id -ieq $machineId }).Name
                        $targetMachinesForPackage += "$machineName ($($machineId))"
                    }
                }
            }
        }

        Write-Verbose "Found $($targetMachinesForPackage.Count) machines for package $($packageId)"
        foreach ($machine in $targetMachinesForPackage) {
            $result = [PsCustomObject]@{
                DeploymentCreated = $deployment.Created
                Status            = "$($task.State) $(If($task.HasWarningsOrErrors -ieq $True) {"(Has Warnings)"})"
                projectName       = $project.Name
                Environment       = $environment.Name
                ServerName        = $machine
                Tenant            = $tenantName
                DeployedBy        = $deployment.DeployedBy
                PackageName       = $packageId
                PackageVersion    = $packageVersion
            }
            $results += $result
        }   
    }    
}

if ($results.Count -gt 0) {
    Write-Host ""
    Write-Host "Found $($results.Count) results:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Host "Exporting results to CSV file: $csvExportPath"
        $results | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
    else {
        $results | Sort-Object -Property DeploymentCreated | Format-Table -Property *
    }
}
