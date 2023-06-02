# Setup
$octopusUrl = "https://youroctopusurl"
$OctopusAPIKey = ""
$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$spaceName = "Default"
$projectName = "Project Name"
$releaseVersion = "0.0.1"
$amtOfDeploymentsToDelete = 0

# Function to delete deployments
function delete($url){
    Invoke-WebRequest $url -Headers $header -Method Delete
}

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get release
$releases = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $header
$release = $releases.Items | Where-Object { $_.Version -eq $releaseVersion }

# Get Deployments
$deploymentsInfo = Invoke-RestMethod -Uri "$OctopusUrl/api/$($space.Id)/releases/$($release.Id)/deployments" -Headers $header

# Print number of deployments available for deletion
Write-Host "Project $ProjectName has $($deploymentsInfo.totalresults) deployments for release $releaseVersion"

# Delete Deployments
$deploymentsToDelete = Invoke-RestMethod -Uri "$OctopusUrl/api/$($space.Id)/releases/$($release.Id)/deployments?skip=$($deploymentsInfo.TotalResults - $amtOfDeploymentsToDelete)&take=$amtOfDeploymentsToDelete" -Headers $header
foreach($deployment in $deploymentsToDelete.items){
    Write-Host "About to delete $($Deployment.id)"
    delete -url "$OctopusUrl$($deployment.links.self)"
}