$OctopusUrl = "" # example https://myoctopus.something.com
$APIKey = ""  # example API-XXXXXXXXXXXXXXXXXXXXXXXXXXX
$environmentName = "Development"
$spaceName = "Default"
$projectName = ""

$header = @{ "X-Octopus-ApiKey" = $APIKey }

## First we need to find the space
$spaceList = Invoke-RestMethod "$OctopusUrl/api/spaces?Name=$spaceName" -Headers $header
$spaceFilter = @($spaceList.Items | Where {$_.Name -eq $spaceName})
$spaceId = $spaceFilter[0].Id
Write-Host "The spaceId for Space Name $spaceName is $spaceId"

## Next, let's find the environment
$environmentList = Invoke-RestMethod "$OctopusUrl/api/$spaceId/environments?skip=0&take=1000&name=$environmentName" -Headers $header
$environmentFilter = @($environmentList.Items | Where {$_.Name -eq $environmentName})
$environmentId = $environmentFilter[0].Id
Write-Host "The environmentId for Environment Name $environmentName in space $spaceName is $environmentId"

## Then, let's find the project
$projects = Invoke-RestMethod  -UseBasicParsing "$OctopusUrl/api/$spaceId/projects/all?skip=0&take=1000&name=$projectName&" -Headers $header
$projectFilter = @($projects | Where {$_.Name -eq $projectName})
$projectId = $projectFilter[0].Id
Write-Host "The projectId for Project Name $projectName in space $spaceName is $projectId"

## Finally, get the evaluated variables for the provided scope
$evaluatedVariables = (Invoke-RestMethod -UseBasicParsing "$OctopusURL/api/$spaceId/variables/preview?project=$projectId&environment=$environmentId" -Headers $header).Variables

Write-Host "Printing evaluated variables for Project Name $projectName and Environment Name $environmentName"
$evaluatedVariables
