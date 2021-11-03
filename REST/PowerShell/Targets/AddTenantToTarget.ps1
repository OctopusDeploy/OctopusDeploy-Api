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

# Get machines
$allMachines = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header)

# Get tenants
$allTenants = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$($space.Id)/tenants/all" -Headers $header)

foreach ($machineName in $machineNames) {
    
    # Get machine
    $machine = $allMachines | Where-Object { $_.Name -eq $machineName }

    # Update tenanted deployment participation
    $machine.TenantedDeploymentParticipation = $tenantedDeploymentParticipation

    foreach ($tenantName in $tenantNames) {
        # Exchange tenant name for tenant ID
        $tenant = $allTenants | Where-Object { $_.name -eq $tenantName }

        # Associate tenant ID to deployment target
        $machine.TenantIds += ($tenant.Id)
    }

    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($machine | ConvertTo-Json -Depth 10) -Headers $header
}