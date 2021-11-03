$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Target tenant deployment participation - select either "Tenanted" or "TenantedOrUntenanted"
$tenantedDeploymentParticipation = "TenantedOrUntenanted"
$machineNames = @("")
$tenantNames = @("")

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

foreach ($machineName in $machineNames) {
    # Get machine
    $machine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object { $_.Name -eq $machineName }

    # Add target role
    $machine.TenantedDeploymentParticipation = $tenantedDeploymentParticipation

    foreach ($tenantName in $tenantNames) {
        # Exchange tenant name for tenant ID
        $tenant = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$($space.Id)/tenants/all" -Headers $header) | Where-Object { $_.name -eq $tenantName }

        # Associate tenant ID to deployment target
        $machine.TenantIds += ($tenant.Id)
    }

    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($machine | ConvertTo-Json -Depth 10) -Headers $header
}