$octopusUrl = "https://YOUR URL" 
$apiKey = "YOUR API KEY"
$projectName = "YOUR PROJECT NAME"
$sourceEnvironmentName = "Staging" 
$destinationEnvironmentName = "Test"
$spaceName = "YOUR SPACE NAME"
$variableNameToUpdate = "MyVariableToFind"
$newValue = "Updated Value"

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item     
    )

    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        $url = "$OctopusUrl/api/$EndPoint"
    }
    else
    {
        $url = "$OctopusUrl/api/$spaceId/$EndPoint"    
    }  

    try
    {        
        if ($null -ne $item)
        {
            $body = $item | ConvertTo-Json -Depth 10
            Write-Verbose $body

            Write-Host "Invoking $method $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' 
        }

        Write-Host "No data to post or put, calling bog standard invoke-restmethod for $url"
        $result = Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'

        return $result               
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-Error "Unauthorized error returned from $url, please verify API key and try again"
            }
            elseif ($_.Exception.Response.statusCode -eq 403)
            {
                Write-Error "Forbidden error returned from $url, please verify API key and try again"
            }
            else
            {                
                Write-Host -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-Host $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API please check the log for more details"
}

$spaceList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $null -item $null -endPoint "spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100"
$space = $spaceList.Items | Where-Object {$_.Name -eq $spaceName}
$spaceId = $space.Id
Write-Host "The space id for space name $spaceName is $spaceId"

$sourceEnvironmentList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "environments?partialName=$([uri]::EscapeDataString($sourceEnvironmentName))&skip=0&take=100"
$sourceEnvironment = $sourceEnvironmentList.Items | Where-Object {$_.Name -eq $sourceEnvironmentName}
$sourceEnvironmentId = $sourceEnvironment.Id
Write-Host "The environment id for environment name $sourceEnvironmentName is $sourceEnvironmentId"

$destinationEnvironmentList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "environments?partialName=$([uri]::EscapeDataString($destinationEnvironmentName))&skip=0&take=100"
$destinationEnvironment = $destinationEnvironmentList.Items | Where-Object {$_.Name -eq $destinationEnvironmentName}
$destinationEnvironmentId = $destinationEnvironment.Id
Write-Host "The environment id for environment name $destinationEnvironmentName is $destinationEnvironmentId"

$projectList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100"
$project = $projectList.Items | Where-Object {$_.Name -eq $projectName}
$projectId = $project.Id
Write-Host "The project id for project name $projectName is $projectId"

Write-Host "I have all the Ids I need, I am going to find the deployment now"
$taskList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $null -item $null -endPoint "tasks?skip=0&environment=$($sourceEnvironmentId)&project=$($projectId)&name=Deploy&states=Success&spaces=$spaceId&includeSystem=false"
if ($taskList.Items.Count -eq 0)
{
    Write-Host "Unable to find a successful deployment for $projectName to $sourceEnvironmentName"
    exit 0
}

$lastDeploymentTask = $taskList.Items[0]
$deploymentId = $lastDeploymentTask.Arguments.DeploymentId
Write-Host "The id of the last deployment for $projectName to $sourceEnvironmentName is $deploymentId"

$deploymentDetails = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "deployments/$deploymentId"
$releaseId = $deploymentDetails.ReleaseId
Write-Host "The release id for $deploymentId is $releaseId"

$releaseDetails = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "releases/$releaseId"
Write-Host "The version number of the most recent release is $($releaseDetails.Version)"

Write-Host "Checking to see if the destination environment is supported"
$channelDetails = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "channels/$($releaseDetails.ChannelId)"
$lifecycleId = $channelDetails.LifecycleId
if ($null -eq $lifecycleId)
{
    $lifecycleId = $project.LifecycleId
}

$lifecycle = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "lifecycles/$lifecycleId/preview"
$destinationEnvironmentFound = $false
$canBeDeployedTo = $true
foreach ($phase in $lifecycle.Phases)
{
    if ($phase.AutomaticDeploymentTargets -contains $destinationEnvironmentId)
    {
        $destinationEnvironmentFound = $true
    }

    if ($phase.OptionalDeploymentTargets -contains $destinationEnvironmentId)
    {
        $destinationEnvironmentFound = $true
    }

    if ($destinationEnvironmentFound -eq $false -and $phase.IsOptionalPhase -eq $false)
    {
        $canBeDeployedTo = $false
    }
}

if ($destinationEnvironmentFound -eq $false)
{
    Write-Host "The destination environment specified $destinationEnvironmentName is not part of the lifecycle $($lifecycle.Name).  Exiting."
    exit 0
}

if ($canBeDeployedTo -eq $false)
{
    Write-Host "The destination environment specified $destinationEnvironmentName is not the first phase in the lifecycle, or all the lifecycles before it are marked as required.  Please select a new destination environment or mark the phases before it as optional. Exit."
    exit 0
}

Write-Host "I now have the release I am looking for and the destination environment is assigned to the channel, time to update the variable value"

$variableSetValues = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "variables/$($project.VariableSetId)"
$variableFound = $false
foreach ($variable in $variableSetValues.Variables)
{
    if ($variable.Name -ne $variableNameToUpdate)
    {
        continue
    }

    ## Replace with your own matching logic
    if ($variable.Scope.Environment -contains $destinationEnvironmentId)
    {
        Write-Host "Variable to update found!"
        $variable.Value = $newValue
        $variableFound = $true
        break
    }
}

if ($variableFound -eq $false)
{
    Write-Host "Unable to find the variable to update, exiting"
    exit 0
}
Write-Host "Updating the variable set values"
$updatedVariableSetValues = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "PUT" -spaceId $spaceId -item $variableSetValues -endPoint "variables/$($project.VariableSetId)"

$newRelease = @{
    ChannelId = $releaseDetails.ChannelId
    ProjectId = $releaseDetails.ProjectId
    ReleaseNotes = $releaseDetails.ReleaseNotes
    SelectedPackages = $releaseDetails.SelectedPackages
    Version = "$($releaseDetails.Version)-UpdatedVariables"
}
$octopusReleaseObject = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "POST" -spaceId $spaceId -item $newRelease -endPoint "releases"

$newDeployment = @{
    EnvironmentId = $destinationEnvironmentId
    ReleaseId = $octopusReleaseObject.ReleaseId
    ExcludedMachines = @()
    ForcePackageDownload = $false
    ForcePackageRedeployment = $false
    FormValue = @{}
    QueueTime = $null
    QueueTimeExpiry = $null
    SkipActions = @()
    SpecificMachineIds = @()
    TenantId = $null
    UseGuidedFailure = $false
}
$newDeployment = Invoke-OctopusApi -octopusUrl $octopusurl -apiKey $apiKey -method "POST" -spaceId $spaceId -item $newDeployment -endPoint "deployments"
