##############################################################################
## This script is an example of how to copy runbooks from one project to 
## another, even cross instance/space
##############################################################################

$ErrorActionPreference = "Stop";

function Get-OctopusItems
{
	# Define parameters
    param(
    	$OctopusUri,
        $ApiKey,
        $SkipCount = 0
    )
    
    # Define working variables
    $items = @()
    $skipQueryString = ""
    $headers = @{"X-Octopus-ApiKey"="$ApiKey"}

    # Check to see if there there is already a querystring
    if ($octopusUri.Contains("?"))
    {
        $skipQueryString = "&skip="
    }
    else
    {
        $skipQueryString = "?skip="
    }

    $skipQueryString += $SkipCount
    
    # Get intial set
    Write-Host "Calling $OctopusUri$skipQueryString"
    $resultSet = Invoke-RestMethod -Uri "$($OctopusUri)$skipQueryString" -Method GET -Headers $headers

    # Check to see if it returned an item collection
    if ($null -ne $resultSet.Items)
    {
        # Store call results
        $items += $resultSet.Items
    
        # Check to see if resultset is bigger than page amount
        if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage))
        {
            # Increment skip count
            $SkipCount += $resultSet.ItemsPerPage

            # Recurse
            $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
        }
    }
    else
    {
        return $resultSet
    }
    

    # Return results
    return $items
}

# Define working variables
$sourceOctopusURL = "https://SourceOctopusServer"
$sourceOctopusAPIKey = "API-SourceApiKey"
$sourceHeader = @{ "X-Octopus-ApiKey" = $sourceOctopusAPIKey }
$sourceSpaceName = "SourceSpaceName"
$sourceProjectName = "SourceProjectName"

$destinationOctopusURL = "https://DestinationOctopusServer"
$destinationOctopusAPIKey = "API-DestinationApiKey"
$destinationHeader = @{ "X-Octopus-ApiKey" = $destinationOctopusAPIKey }
$destinationSpaceName = "DestinationSpaceName"
$destinationProjectName = "DestinationProjectName"

$externalFeedName = "Docker Hub"
$workerPoolName = "Azure Worker Pool"

# Get space
Write-Host "Getting source space ..."
$sourceSpaces = Get-OctopusItems -OctopusUri "$sourceOctopusURL/api/spaces" -ApiKey $sourceOctopusAPIKey
$sourceSpace = $sourceSpaces | Where-Object {$_.Name -eq $sourceSpaceName}

# Get project
Write-Host "Gettings source proect ..."
$sourceProject = (Get-OctopusItems -OctopusUri "$sourceOctopusURL/api/$($sourceSpace.Id)/projects" -ApiKey $sourceOctopusAPIKey) | Where-Object {$_.Name -eq $sourceProjectName}

# Get project runbooks
Write-Host "Getting source runbooks ..."
$sourceProjectRunbooks = (Get-OctopusItems -OctopusUri "$sourceOctopusURL/api/$($sourceSpace.Id)/runbooks" -ApiKey $sourceOctopusAPIKey) | Where-Object {$_.ProjectId -eq $sourceProject.Id}

# Get destination space
Write-Host "Getting destination space ..."
$destinationSpaces = Get-OctopusItems -OctopusUri "$destinationOctopusURL/api/spaces" -ApiKey $destinationOctopusAPIKey
$destinationSpace = $destinationSpaces | Where-Object {$_.Name -eq $destinationSpaceName}

# Get destination project
Write-Host "Getting destination project ..."
$destinationProject = (Get-OctopusItems -OctopusUri "$destinationOctopusURL/api/$($destinationSpace.Id)/projects" -ApiKey $destinationOctopusAPIKey) | Where-Object {$_.Name -eq $destinationProjectName}

##############################################################################
## If you need to reference an external feed on the destination
##############################################################################
Write-Host "Getting destination Docker Hub feed ..."
$destinationDockerHubFeed = (Get-OctopusItems -OctopusUri "$destinationOctopusURL/api/$($destinationSpace.Id)/feeds" -ApiKey $destinationOctopusAPIKey) | Where-Object {$_.Name -eq $externalFeedName}

##############################################################################
## If you need to reference a worker pool for steps
##############################################################################
Write-Host "Getting destination worker pool Azure Worker Pool"
$destinationWorkerPool = (Get-OctopusItems -OctopusUri "$destinationOctopusUrl/api/$($destinationSpace.Id)/workerpools" -ApiKey $destinationOctopusAPIKey) | Where-Object {$_.Name -eq $workerPoolName}

# Loop through the runbooks
foreach ($sourceRunbook in $sourceProjectRunbooks)
{
    Write-Host "Getting destination runbooks ..."
    $destinationProjectRunbooks = (Get-OctopusItems -OctopusUri "$destinationOctopusURL/api/$($destinationSpace.Id)/runbooks" -ApiKey $destinationOctopusAPIKey) | Where-Object {$_.ProjectId -eq $destinationProject.Id}
    
    if ($null -ne ($destinationProjectRunbooks | Where-Object {$_.Name -eq $sourceRunbook.Name}))
    {
        Write-Warning "Destination project ($($destinationProject.Name)) already has a runbook called $($sourceRunbook.Name), skipping ..."
        continue
    }

    # Get the runbook process
    Write-Host "Getting process for runbook $($sourceRunbook.Name) ..."
    $runbookProcess = Get-OctopusItems -OctopusUri "$sourceOctopusURL/api/$($sourceSpace.Id)/runbookProcesses/$($sourceRunbook.RunbookProcessId)" -ApiKey $sourceOctopusAPIKey


    Write-Host "Updating process for copy ..."
    # Make updates for destionation
    foreach ($step in $runbookProcess.Steps)
    {
       foreach ($action in $step.Actions)
       {
            $action.Id = $null

            # Check for container
            if ($null -ne $action.Container.FeedId)
            {
                # Update feed
                $action.Container.FeedId = $destinationDockerHubFeed.Id
            }

            if ($null -ne $action.Environments)
            {
                # Update to null
                $action.Environments = $null
            }

            if ($null -ne $action.WorkerPoolId)
            {
                $action.WorkerPoolId = $destinationWorkerPool.Id
            }
       }

       $step.Id = $null

       # Update role
       if ($null -ne $step.Properties.'Octopus.Action.TargetRoles')
       {
           $step.Properties.'Octopus.Action.TargetRoles' = "demo-k8s-cluster"
       }

    }

    # Update runbook properties
    $runbookProcess.Id = $null
    $runbookProcess.PSObject.Properties.Remove("SpaceId")
    $runbookProcess.ProjectId = $destinationProject.Id
    $sourceRunbook.Id = $null
    $sourceRunbook.PSObject.Properties.Remove("Id")
    $sourceRunbook.ProjectId = $destinationProject.Id
    $sourceRunbook.SpaceId = $destinationProject.SpaceId
    $sourceRunbook.RunbookProcessId = $null
    $sourceRunbook.PSObject.Properties.Remove("Environments")
    $sourceRunbook.EnvironmentScope = "All"
    $sourceRunbook.MultiTenancyMode = "Untenanted"

    # Create destination runbook
    Write-Host "Creating destination runbook $($sourceRunbook.Name)..."
    $destinationRunbook = Invoke-RestMethod -Method Post -Uri "$destinationOctopusURL/api/$($destinationSpace.Id)/runbooks" -Body ($sourceRunbook | ConvertTo-Json -Depth 10) -Headers $destinationHeader -ContentType "application/json;charset=utf-8"

    Write-Host "Getting runbook process on destination ..."
    $destinationProcess = Get-OctopusItems -OctopusUri "$destinationOctopusURL/api/$($destinationSpace.Id)/RunbookProcesses/$($destinationRunbook.RunbookProcessId)" -ApiKey $destinationOctopusAPIKey

    $destinationProcess.Steps = $runbookProcess.Steps

    Write-Host "Updating destination steps with source steps ..."
    Invoke-RestMethod -Method Put -Uri "$destinationOctopusURL/api/$($destinationSpace.Id)/RunbookProcesses/$($destinationRunbook.RunbookProcessId)" -Body ($destinationProcess | ConvertTo-Json -Depth 10) -Headers $destinationHeader
}