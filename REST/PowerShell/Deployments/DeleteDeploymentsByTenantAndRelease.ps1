# This script will delete all Deployments for a given release and tenant combination for a specified project
$ErrorActionPreference = 'Stop'

# Setup
$octopusUrl = "https://YOUR_OCTOPUS_URL"
$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$spaceName = "YOUR_SPACE"
$projectName = "PROJECT_NAME"
$releaseVersion = "0.0.1"
$tenantName = "TENANT_NAME"

$dryRun = $true #set to $true to see a list of DeploymentIds that will be deleted !! set to $false to delete the DeploymentIds

# Function to delete deployments
function delete($url){
    Invoke-WebRequest $url -Headers $header -Method Delete
}

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get Tenant
$tenant = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/all" -Headers $header) | Where-Object {$_.Name -eq $tenantName}

# Get release
$releases = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $header
$release = $releases.Items | Where-Object { $_.Version -eq $releaseVersion }

# Get Deployments
$deploymentsInfo = Invoke-RestMethod -Uri "$OctopusUrl/api/$($space.Id)/releases/$($release.Id)/deployments" -Headers $header

# Print number of deployments available for deletion
Write-Host "Project $ProjectName has $($deploymentsInfo.totalresults) deployments for release $releaseVersion"

# Delete Deployments
$listOfDeployments = Invoke-RestMethod -Uri "$OctopusUrl/api/$($space.Id)/releases/$($release.Id)/deployments" -Headers $header
$deploymentsToDelete = $($listOfDeployments.Items) | Where-Object {$_.TenantId -eq $($tenant.Id)}

foreach($deployment in $deploymentsToDelete){
    Write-Host "Attempting to delete $($Deployment.id)"
    if(!$dryRun){
        delete -url "$OctopusUrl$($deployment.links.self)"
        Write-Host "... Done!"
    }
    if($dryRun){
        Write-Host "`$dryRun = `$true, no changes made!"
    }
}
