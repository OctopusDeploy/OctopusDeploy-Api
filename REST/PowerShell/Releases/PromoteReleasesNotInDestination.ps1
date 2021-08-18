$octopusUrl = "https://local.octopusdemos.app" 
$apiKey = "YOUR API KEY"
$projectNameList = "WebAPI,Web UI"
$sourceEnvironmentName = "Production" 
$destinationEnvironmentName = "Staging"
$spaceName = "Default"

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

$splitProjectList = $projectNameList -split ","
foreach ($projectName in $splitProjectList)
{
    $projectList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100"
    $project = $projectList.Items | Where-Object {$_.Name -eq $projectName}
    $projectId = $project.Id
    Write-Host "The project id for project name $projectName is $projectId"

    Write-Host "I have all the Ids I need, I am going to find the most recent sucesseful deployment now to $sourceEnvironmentName"
    $taskList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $null -item $null -endPoint "tasks?skip=0&environment=$($sourceEnvironmentId)&project=$($projectId)&name=Deploy&states=Success&spaces=$spaceId&includeSystem=false"
    if ($taskList.Items.Count -eq 0)
    {
        Write-Host "Unable to find a successful deployment for $projectName to $sourceEnvironmentName"
        continue
    }

    $lastDeploymentTask = $taskList.Items[0]
    $deploymentId = $lastDeploymentTask.Arguments.DeploymentId
    Write-Host "The id of the last deployment for $projectName to $sourceEnvironmentName is $deploymentId"

    $deploymentDetails = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "deployments/$deploymentId"
    $releaseId = $deploymentDetails.ReleaseId
    Write-Host "The release id for $deploymentId is $releaseId"

    $canPromote = $false
    Write-Host "I have all the Ids I need, I am going to find the most recent sucesseful deployment now to $destinationEnvironmentName"
    $destinationTaskList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $null -item $null -endPoint "tasks?skip=0&environment=$($destinationEnvironmentId)&project=$($projectId)&name=Deploy&states=Success&spaces=$spaceId&includeSystem=false"
    
    if ($destinationTaskList.Items.Count -eq 0)
    {
        Write-Host "The destination has no releases, promoting."
        $canPromote = $true
    }

    $lastDestinationDeploymentTask = $destinationTaskList.Items[0]
    $lastDestinationDeploymentId = $lastDestinationDeploymentTask.Arguments.DeploymentId
    Write-host "The deployment id of the last deployment for $projectName to $destinationEnvironmentName is $lastDestinationDeploymentId"

    $lastDestinationDeploymentDetails = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $apiKey -method "GET" -spaceId $spaceId -item $null -endPoint "deployments/$lastDestinationDeploymentId"
    $lastDestinationReleaseId = $lastDestinationDeploymentDetails.ReleaseId

    Write-Host "The release id for the last deployment to the destination is $lastDestinationReleaseId"

    if ($lastDestinationReleaseId -ne $releaseId)
    {
        Write-Host "The releases on the source and destination don't match, promoting"
        $canPromote = $true
    }
    else
    {
        Write-Host "The releases match, not promoting"    
    }

    if ($canPromote -eq $false)
    {
        Write-Host "Nothing to promote for $projectName"
        continue
    }

    $newDeployment = @{
        EnvironmentId = $destinationEnvironmentId
        ReleaseId = $releaseId
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
}