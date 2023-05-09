$OctopusServerUrl = "https://YOUR_OCTOPUS_URL"  #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  #PUT YOUR API KEY HERE
$SpaceId = "Spaces-XX" # (e.g. Spaces-1)
$TenantId = "Tenants-XX"  #TenantID to remove (e.g. Tenants-12)
$AccountId = "Accounts-XX"  #AccountID to modify (e.g. Accounts-213)

$Body = Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($SpaceId)/accounts/$($AccountId)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" }

$NewTenantList = @()
$Tenants = $Body.TenantIds

Foreach ($Tenant in $Tenants) {
    Write-Host "$($Tenant)"
    if ($Tenant -eq $TenantId) {
        Write-Host "$($TenantId) removed from $($AccountId)"
    }
    
    if ($Tenant -ne $TenantId) {
        $NewTenantList += $Tenant
    }
}

$Body.TenantIds = $NewTenantList
   
Invoke-RestMethod -Method PUT -Uri "$OctopusServerUrl/api/$($SpaceId)/accounts/$($AccountId)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -body ($Body | ConvertTo-Json)