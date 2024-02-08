$octopusURL = "YOUR OCTOPUS URL"
$apiKey = "YOUR OCTOPUS API KEY"
$spaceName = "YOUR SPACE NAME"
$headers = @{ "X-Octopus-ApiKey" = $apiKey }

#Get space ID
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}
$spaceId = $($space.Id)

# Get all projects in the specified space
$projectListUrl = "$octopusURL/api/$spaceId/projects/all"
$projects = Invoke-RestMethod -Uri $projectListUrl -Method Get -Headers $headers

# Loop through each project to find the latest deployment
foreach ($project in $projects) 
{
    $deploymentsUrl = "$octopusURL/api/$spaceId/deployments?projects=$($project.Id)&take=1"
    $latestDeployment = Invoke-RestMethod -Uri $deploymentsUrl -Method Get -Headers $headers -ErrorAction Stop | Select-Object -ExpandProperty Items | Select-Object -First 1

    if ($latestDeployment) 
    {
        $releaseId = $latestDeployment.ReleaseId
        $releaseUrl = "$octopusURL/api/$spaceId/releases/$releaseId"
        $release = Invoke-RestMethod -Uri $releaseUrl -Method Get -Headers $headers

        #Convert date
        $deploymentDate = Get-Date $latestDeployment.Created -Format "MMM-d-yyyy HH:mm:ss"

        Write-Output "Project: $($project.Name), Latest release: $($release.Version), Latest deployment: $deploymentDate"
    } 
    else 
    {
        Write-Output "Project: $($project.Name) has no deployments."
    }
}