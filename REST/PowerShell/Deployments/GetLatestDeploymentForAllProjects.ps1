###############################################################################################################################################################
# NOTE: This script only finds the initial deployment to an environment. Deployments to individual targets via a Deployment Target Trigger are not detected.  #
# NOTE: Use this script as a first pass to find projects that have not been deployed recently, but always verify the results.                                 #
###############################################################################################################################################################

$octopusURL = "YOUR OCTOPUS URL"
$apiKey = "YOUR OCTOPUS API KEY"
$spaceName = "YOUR SPACE NAME"
$outputFilePath = "DIRECTORY TO OUTPUT\OctopusProjectsLatestDeployment.csv"
$headers = @{ "X-Octopus-ApiKey" = $apiKey }

# Get space ID
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $headers) | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id
$octopusSpaceUrl = "$octopusURL/api/$spaceId"

$showProgress = $true

# Get first page of projects
$take = 30
$count = 1
$pageNumber = 0
Write-Host "Getting page 1 of projects for space $spaceId"
$projects = Invoke-RestMethod -Uri "$octopusSpaceUrl/projects?take=$take" -Headers $headers
$total = $projects.TotalResults

# Initialize an array to hold the project details
$projectDetails = @()

Write-Host "---"
Write-Host "Calculating the latest deployment date for $total projects (this may take some time!)."
Write-Host "---"

while ($pageNumber -le $projects.LastPageNumber) {
    foreach ($project in $projects.Items) {
        $per = [math]::Round($count / $total * 100.0, 2) - 1

        if ($showProgress) {
            Write-Progress -Activity "Checking project $($project.Name)".PadRight(60) -Status "$count/$total ($per% Complete)" -PercentComplete $per
        }
        
        $deploymentsUrl = "$octopusSpaceUrl/deployments?projects=$($project.Id)&take=1"
        try {
            $latestDeployment = Invoke-RestMethod -Uri $deploymentsUrl -Method Get -Headers $headers -ErrorAction Stop | Select-Object -ExpandProperty Items | Select-Object -First 1

            if ($null -ne $latestDeployment) {
                $releaseId = $latestDeployment.ReleaseId
                $releaseUrl = "$octopusURL/api/$spaceId/releases/$releaseId"
                $release = Invoke-RestMethod -Uri $releaseUrl -Method Get -Headers $headers

                $deploymentDate = Get-Date $latestDeployment.Created -Format "MMM-d-yyyy"

                $projectDetails += [PSCustomObject]@{
                    Project          = $project.Name
                    ProjectId        = $project.Id
                    LatestRelease    = $release.Version
                    LatestDeployment = $deploymentDate
                    Timestamp        = $latestDeployment.Created
                }
            }
            else {
                $projectDetails += [PSCustomObject]@{
                    Project          = $project.Name
                    ProjectId        = $project.Id
                    LatestRelease    = "N/A"
                    LatestDeployment = "N/A"
                    Timestamp        = 0
                }
            }
        }
        catch {
            $projectDetails += [PSCustomObject]@{
                Project          = $project.Name
                ProjectId        = $project.Id
                LatestRelease    = "Failed to retrieve"
                LatestDeployment = "Failed to retrieve"
                Timestamp        = 0
            }
        }

        $count += 1
    }
    $pageNumber += 1
    $skip = $pageNumber * $take
    if ($pageNumber -gt $projects.LastPageNumber) {
        break
    }

    Write-Host "Getting page $($pageNumber + 1) of projects for space $spaceId"
    $projects = Invoke-RestMethod -Uri "$octopusSpaceUrl/projects?skip=$skip&take=$take" -Headers $headers
}

if ($showProgress) {
    Write-Progress -Activity "Creating $outputFilePath".PadRight(60) -Status "Almost done" -PercentComplete 100
}

$projectDetails | Sort-Object -Property Timestamp -Descending | Export-Csv -Path $outputFilePath -NoTypeInformation

Start-Sleep -Seconds 1

if ($showProgress) {
    Write-Progress -Activity "Export complete.".PadRight(60) -Status "100% Complete" -PercentComplete 100
}

Write-Host "Export completed. File saved at: $outputFilePath"
