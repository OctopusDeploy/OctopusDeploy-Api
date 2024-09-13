# =============================================================== #
#      Removes a Tenant from existing and archived certificates   #
# =============================================================== #

$ErrorActionPreference = "Stop";

# Define working variables
$OctopusURL = "https://your.octopus.app"
$OctopusAPIKey = "API-KEY"
$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$spaceName = "Default"
$tenantName = "TenantName"

# Set this flag to $False to actually perform the operation
$WhatIf = $True

# Get Space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# Find Tenant
$tenants = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
$tenant = $tenants.Items | Where-Object { $_.Name -ieq $tenantName } | Select-Object -First 1

Write-Output "Retrieving all current certificates for tenant"
$currentCerts = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/certificates?tenant=$($tenant.Id)&skip=0&take=100" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $currentCerts += $response.Items
} while ($response.Links.'Page.Next')

Write-Output "Retrieving all archived certificates for tenant"
$archivedCerts = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/certificates?tenant=$($tenant.Id)&archived=true&skip=0&take=100" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $archivedCerts += $response.Items
} while ($response.Links.'Page.Next')

if ($currentCerts.Count -eq 0 -and $archivedCerts.Count -eq 0) {
  Write-Output "No certificates found for tenant '$($tenant.Name)'"
  return
}
else {
    Write-Host "Working on current certificates"
    foreach($cert in $currentCerts) {
        if ($WhatIf) {
            Write-Output "WhatIf: Would have removed tenant '$($tenant.Name)' association with certificate '$($cert.Name)'"
        }
        else {
            Write-Output "Removing tenant '$($tenant.Name)' association with certificate '$($cert.Name)'"
            $cert.TenantIds = $cert.TenantIds | Where-Object { $_ -ne $tenant.Id }
            if($cert.TenantIds.Length -eq 0 -and $cert.TenantedDeploymentParticipation -ieq "Tenanted") {
                Write-Warning "Removing tenant assocation from archived certificate '$($cert.Name)' would cause no tenants to be linked. Changing TenantedDeploymentParticipation to TenantedOrUntenanted"
                $cert.TenantedDeploymentParticipation = "TenantedOrUntenanted"
            }
            $certBody = $cert | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/certificates/$($cert.Id)" -Body $certBody -Headers $header
        }
    }

    Write-Host "Working on archived certificates"
    foreach($cert in $archivedCerts) {
        if ($WhatIf) {
            Write-Output "WhatIf: Would have removed tenant '$($tenant.Name)' association with archived certificate '$($cert.Name)' ($($cert.Id))"
        }
        else {
            Write-Output "Removing tenant '$($tenant.Name)' association with archived certificate '$($cert.Name)' ($($cert.Id))"
            $cert.TenantIds = @($cert.TenantIds | Where-Object { $_ -ne $tenant.Id })
            if($cert.TenantIds.Length -eq 0 -and $cert.TenantedDeploymentParticipation -ieq "Tenanted") {
                Write-Warning "Removing tenant assocation from archived certificate '$($cert.Name)' would cause no tenants to be linked. Changing TenantedDeploymentParticipation to TenantedOrUntenanted"
                $cert.TenantedDeploymentParticipation = "TenantedOrUntenanted"
            }
            $certBody = $cert | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/certificates/$($cert.Id)" -Body $certBody -Headers $header
        }
    }
}