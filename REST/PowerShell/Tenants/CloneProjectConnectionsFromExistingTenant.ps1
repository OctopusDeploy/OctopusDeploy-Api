# ===========================================================
#      Clone Project connections from an existing Tenant
# ===========================================================

$ErrorActionPreference = "Stop";

# Define working variables
$OctopusURL = "http://YOUR_OCTOPUS_URL"
$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$SpaceId = "Spaces-1"
$SourceTenantName = "SOURCE_TENANT_NAME"
$DestinationTenantName = "DESTINATION_TENANT_NAME"

# Find Tenant IDs
$SourceTenant = (Invoke-RestMethod -Method GET "$OctopusURL/api/$($SpaceId)/Tenants/all" -Headers $Header) | Where-Object {$_.Name -eq $SourceTenantName}
$DestinationTenant = (Invoke-RestMethod -Method GET "$OctopusURL/api/$($SpaceId)/Tenants/all" -Headers $Header) | Where-Object {$_.Name -eq $DestinationTenantName}

# Modify $DestinationTenant to match .ProjectEnviroments with $SourceTenant
$DestinationTenant.ProjectEnvironments = $SourceTenant.ProjectEnvironments

# Commit
Invoke-RestMethod -Method PUT "$OctopusURL/api/$($SpaceId)/Tenants/$($DestinationTenant.Id)" -Body ($DestinationTenant | ConvertTo-Json -Depth 10) -Headers $Header
Write-Host "Done!"
Write-Warning "Please check your Tenant Common Variables before deploying via: `"$OctopusURL/app#/$($SpaceId)/Tenants/$($DestinationTenant.Id)/variables?activeTab=commonVariables`""
