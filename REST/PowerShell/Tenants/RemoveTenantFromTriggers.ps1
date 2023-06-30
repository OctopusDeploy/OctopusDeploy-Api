# =========================================================
#      Removes a Tenant from existing Project Triggers
# =========================================================

$ErrorActionPreference = "Stop";

# Define working variables
$OctopusURL = "http://YOUR_OCTOPUS_URL"
$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$SpaceId = "Spaces-1"
$TenantName = "YOUR_TENANT_NAME"

# Find Tenant ID
$Tenant = (Invoke-RestMethod -Method GET "$OctopusURL/api/$($SpaceId)/Tenants/all" -Headers $Header) | Where-Object {$_.Name -eq $TenantName}


# Find Triggers that include $Tenant.Id
$TriggersList = (Invoke-RestMethod -Method GET "$OctopusURL/api/$($SpaceId)/projecttriggers" -Headers $Header) | Where-Object {$_.Items.Action.TenantIds -contains $($Tenant.Id)}
$Triggers = $TriggersList.items
Foreach ($Trigger in $Triggers) {
    $TriggerTenantIds = $Trigger.Action.TenantIds
    $Trigger.Action.TenantIds = @()
    Foreach ($TriggerTenantId in $TriggerTenantIds) {
        If ($TriggerTenantId -ne $($Tenant.Id)) {
            $Trigger.Action.TenantIds += $TriggerTenantId
        }
        Invoke-RestMethod -Method PUT "$OctopusURL/api/$($SpaceId)/projects/$($Trigger.ProjectId)/triggers/$($Trigger.Id)" -Body ($Trigger | ConvertTo-Json -Depth 10) -Headers $Header
    }
}