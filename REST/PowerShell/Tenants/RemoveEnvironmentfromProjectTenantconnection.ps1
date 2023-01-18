$whatif = $false #set to $true for a dry run where no changes are committed, set to $false to commit changes

$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" 
$OctopusUrl = "YOUR_OCTOPUS_URL" # No trailing slashes example = "http://octopusinstance.bla"
$TenantId = "Tenants-XX" # Tenant ID you wish to remove Environments from
$SpaceId = "Spaces-XX" # Space ID where the Tenant specified above resides
$EnvironmentId = "Environments-XX" # Environment ID you want to remove

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$tenant = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$($SpaceId)/tenants/$($TenantId)" -Headers $header

write-host "˅========Old JSON Between These Lines========˅"
$tenant | ConvertTo-Json
write-host "˄========Old JSON Between These Lines========˄"
write-host ""

$projectIds = @()
$projectEnvironments = @{}
foreach ($Obj in $tenant.ProjectEnvironments.PSObject.Properties) {
    $environmentIds = @()
    foreach ($environment in $Obj.value) {
        if ($environment -ne $EnvironmentId) {
            $environmentIds += $environment
        }
    }
    $projectEnvironments.Add($Obj.Name,$environmentIds)
}


# Build json payload
$jsonPayload = @{
    Name = $tenant.Name
    TenantTags = $tenant.TenantTags
    SpaceId = $SpaceId
    ProjectEnvironments = $projectEnvironments
}

write-host "˅======Updated JSON Between These Lines======˅"
$jsonPayload | ConvertTo-Json
write-host "^======Updated JSON Between These Lines======^"
write-host ""

# Upload Tenant JSON payload
if ($whatif -eq $false) {
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($SpaceId)/tenants/$($TenantId)" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header -ContentType "application/json"
    }
Else {
    write-host "Dry run detected. Set `$whatif to `$false to commit changes."
}

write-host "Done"
