# Define Octopus variables
$octopusURL = "https://youroctopusurl"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Define working variables
$spaceName = "Default"
$channelName = "Default"
$machineName = "MyMachineName"
# This is the url-friendly name of the project e.g. "My Project" would be "my-project"
$projectSlug = "my-project"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get machine details
    $matchingMachines = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines?partialName=$machineName" -Headers $header)
    $machine = $matchingMachines.Items | Select-Object -First 1

    # Tweak this to change the number of machine tasks returned
    $machineTaskCount = 100
    
    # Get machine tasks
    $machineTaskSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)/tasks?skip=0&take=$machineTaskCount" -Headers $header)
    $machineTaskDeploymentIds = $machineTaskSearch.Items | Select-Object @{Name="DeploymentIds"; Expression={ $_.Arguments.DeploymentId}} | Select-Object -ExpandProperty DeploymentIds
    
    # Get project details
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$projectSlug" -Headers $header)

    # Get matching project channel
    $channels = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/channels?partialName=$channelName" -Headers $header)
    $channel = $channels.Items | Select-Object -First 1
    
    # Tweak this to change the number of release records returned
    $releaseCount = 100
    
    # Get project releases
    $releases = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases?skip=0&take=$releaseCount" -Headers $header)
    
    # Get latest release matching project channel
    $latestRelease = $releases.Items | Where-Object {$_.ChannelId -eq $($channel.Id)} | Select-Object -First 1
        
    # Tweak this to change the number of deployment records returned
    $deploymentCount = 100

    # Get release deployments
    $releaseDeploymentsResource = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/releases/$($latestRelease.Id)/deployments?skip=0&take=$deploymentCount" -Headers $header)
    $releaseDeployments = $releaseDeploymentsResource.Items

    # Search release deployments for machine task deployment Id.
    $foundRelease = $False
    foreach($deployment in $releaseDeployments)
    {
        $releaseDeploymentId = $deployment.Id
        if($machineTaskDeploymentIds -contains $releaseDeploymentId) {
            $foundRelease = $True
        }
    }
    if($foundRelease -eq $False)
    {
        Write-Host "Couldnt find release $($latestRelease.Version) for machine $($machine.Name)"
    }
}   
catch
{
    Write-Host $_.Exception.Message
}