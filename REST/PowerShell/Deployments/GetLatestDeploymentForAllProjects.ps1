$octopusURL = "YOUR OCTOPUS URL"
$apiKey = "YOUR OCTOPUS API KEY"
$spaceName = "YOUR SPACE NAME"
$outputFilePath = "DIRECTORY TO OUTPUT\OctopusProjectsLatestDeployment.csv"
$headers = @{ "X-Octopus-ApiKey" = $apiKey }

# Get space ID
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $headers) | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

# Get all projects in the specified space
$projectListUrl = "$octopusURL/api/$spaceId/projects/all"
$projects = Invoke-RestMethod -Uri $projectListUrl -Method Get -Headers $headers

# Initialize an array to hold the project details
$projectDetails = @()

Write-Host "---"
Write-Host "Calculating the latest deployment date for $($projects.count) projects (this may take some time!)."
Write-Host "---"

foreach ($project in $projects) 
{
    $deploymentsUrl = "$octopusURL/api/$spaceId/deployments?projects=$($project.Id)&take=1"
    try {
        $latestDeployment = Invoke-RestMethod -Uri $deploymentsUrl -Method Get -Headers $headers -ErrorAction Stop | Select-Object -ExpandProperty Items | Select-Object -First 1

        if ($null -ne $latestDeployment) 
        {
            $releaseId = $latestDeployment.ReleaseId
            $releaseUrl = "$octopusURL/api/$spaceId/releases/$releaseId"
            $release = Invoke-RestMethod -Uri $releaseUrl -Method Get -Headers $headers

            $deploymentDate = Get-Date $latestDeployment.Created -Format "MMM-d-yyyy"

            $projectDetails += [PSCustomObject]@{
                Project = $project.Name
                ProjectId = $project.Id
                LatestRelease = $release.Version
                LatestDeployment = $deploymentDate
            }
        } else {
            $projectDetails += [PSCustomObject]@{
                Project = $project.Name
                ProjectId = $project.Id
                LatestRelease = "N/A"
                LatestDeployment = "N/A"
            }
        }
    } catch {
        $projectDetails += [PSCustomObject]@{
            Project = $project.Name
            ProjectId = $project.Id
            LatestRelease = "Failed to retrieve"
            LatestDeployment = "Failed to retrieve"
        }
    }
}

$projectDetails | Export-Csv -Path $outputFilePath -NoTypeInformation

Write-Host "Export completed. File saved at: $outputFilePath"
