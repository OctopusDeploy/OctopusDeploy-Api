# ====================================================
#      Remove all Project connections to a Tenant
# ====================================================

$ErrorActionPreference = "Stop";

# Define working variables
$OctopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$Header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$SpaceId = "Spaces-1"
$TenantToDisconnectFromProjects = "TENANT_NAME_HERE"

# Find Tenant ID
$Tenant = (Invoke-RestMethod -Method GET "$OctopusURL/api/$($SpaceId)/Tenants/all" -Headers $Header) | Where-Object {$_.Name -eq $TenantToDisconnectFromProjects}

$Tenant.ProjectEnvironments = @{}
   
Invoke-RestMethod -Method PUT "$OctopusURL/api/$($SpaceId)/Tenants/$($Tenant.Id)" -Body ($Tenant | ConvertTo-Json -Depth 10) -Headers $Header
Write-Host "Done!"
