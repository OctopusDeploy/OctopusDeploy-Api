$OctopusURL = "YOUR INSTANCE URL" #example: https://octopus.samples.app
$SpaceName = "YOUR SPACE NAME" 
$APIKey = "YOUR API KEY"
$projectName = "YOUR PROJECT NAME"
$releaseVersion = "YOUR RELEASE VERSION"
$environmentName = "YOUR ENVIRONMENT NAME"
$fileDownloadPath = "LOCATION FOR DOWNLOADED ARTIFACT"
$fileNameForOctopus = "NAME FOR OCTOPUS" ## Must include file extension in name!

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting the space information"
$spaceList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/spaces?skip=0&take=10&partialName=$([System.Web.HTTPUtility]::UrlEncode($spaceName))" -Headers $header
$space = $spaceList.Items | Where-Object {$_.Name -eq $spaceName}
$spaceId = $space.Id
Write-Host "The space-id for $spaceName is $spaceId"

Write-Host "Getting the environment information"
$environmentList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/environments?skip=0&take=10&partialName=$([System.Web.HTTPUtility]::UrlEncode($environmentName))" -Headers $header
$environment = $environmentList.Items | Where-Object {$_.Name -eq $environmentName}
$environmentId = $environment.Id
Write-Host "The id of $environmentName is $environmentId"

Write-Host "Getting the project information"
$projectList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/projects?skip=0&take=10&partialName=$([System.Web.HTTPUtility]::UrlEncode($projectName))" -Headers $header
$project = $projectList.Items | Where-Object {$_.Name -eq $projectName}
$projectId = $project.Id
Write-Host "The id of $projectName is $projectId"

Write-Host "Getting the release information"
$releaseList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/projects/$projectId/releases?skip=0&take=100&searchByVersion=$releaseVersion" -Headers $header
$release = $releaseList.Items | Where-Object {$_.Version -eq $releaseVersion}
$releaseId = $release.Id
Write-Host "The id of $releaseVersion is $releaseId"

Write-Host "Getting the deployment information"
$deploymentList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/releases/$releaseId/deployments?skip=0&take=1000" -Headers $header
$deploymentsToEnivronment = @($deploymentList.Items | Where-Object {$_.EnvironmentId -eq $environmentId})
$deploymentToUse = $null
$previousDate = Get-Date
$previousDate = $previousDate.AddDays(-10000)

foreach ($deployment in $deploymentsToEnvironment)
{
    if ($deployment.Created -gt $previousDate)
    {
        $previousDate = $deployment.Created
        $deploymentToUse = $deployment
    }
}

$serverTaskId = $deploymentToUse.TaskId
Write-Host "The server task id of the most recent deployment to $environmentName for release $releaseVersion is $serverTaskId"

$artifactList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/artifacts?regarding=$serverTaskId" -Headers $header
$artifact = $artifactList.Items | Where-Object {$_.Filename -eq $fileNameForOctopus}
$artifactId = $artifact.Id
Write-Host "Found $artifactId that matches expected file name $filenameForOctopus"

Write-Host "Getting file content"
Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/artifacts/$artifactId/content" -Headers $header -OutFile $fileDownloadPath
