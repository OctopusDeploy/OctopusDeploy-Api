$octopusURL = "YOUR OCTOPUS URL"
$apiKey = "YOUR OCTOPUS API KEY"
$spaceName = "YOUR SPACE NAME"
$outputFilePath = "DIRECTORY TO OUTPUT\OctopusTenantsLatestDeployment.csv"
$headers = @{ "X-Octopus-ApiKey" = $apiKey }

# Get space ID
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $headers) | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

# Get all tenants in the specified space
$tenantListUrl = "$octopusURL/api/$spaceId/tenants/all"
$tenants = Invoke-RestMethod -Uri $tenantListUrl -Method Get -Headers $headers

# Initialize an array to hold the tenant details
$results = @()

Write-Host "---"
Write-Host "Calculating the latest deployment for $($tenants.count) tenants (this may take some time!)."
Write-Host "---"

# Loop through each tenant to find the latest deployment
foreach ($tenant in $tenants) 
{
    $deploymentsUrl = "$octopusURL/api/$spaceId/deployments?tenants=$($tenant.Id)&take=1"
    $latestDeployment = Invoke-RestMethod -Uri $deploymentsUrl -Method Get -Headers $headers -ErrorAction Stop | Select-Object -ExpandProperty Items | Select-Object -First 1

    if ($null -ne $latestDeployment) 
    {
        # Convert date
        $deploymentDate = Get-Date $latestDeployment.Created -Format "MMM-d-yyyy"
        $row = New-Object PSObject -Property @{
            TenantName = $tenant.Name
            TenantID = $tenant.Id
            LastDeploymentDate = $deploymentDate
        }
    } 
    else 
    {
        $row = New-Object PSObject -Property @{
            TenantName = $tenant.Name
            TenantID = $tenant.Id
            LastDeploymentDate = "No deployments"
        }
    }
    $results += $row
}

# Export results to CSV
$results | Export-Csv -Path $outputFilePath -NoTypeInformation

Write-Host "Export completed. File saved at: $outputFilePath"
