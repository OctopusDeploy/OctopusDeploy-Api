$Whatif = $true #set to $true for a dry run where no changes are committed, set to $false to commit changes

$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" 
$OctopusUrl = "YOUR_OCTOPUS_URL" # No trailing slashes example = "http://octopusinstance.bla"
$TenantId = "Tenants-XX" # Tenant ID you wish to remove Environments from
$SpaceId = "Spaces-XX" # Space ID where the Tenant specified above resides
$ProjectId = "Projects-XX" # Project ID you want to remove

$Header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$Tenant = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$($SpaceId)/tenants/$($TenantId)" -Headers $Header

write-host "˅========Old JSON Between These Lines========˅"
$Tenant | ConvertTo-Json
write-host "˄========Old JSON Between These Lines========˄"
write-host ""

$ProjectIds = @()
$ProjectEnvironments = @{}
foreach ($Obj in $Tenant.ProjectEnvironments.PSObject.Properties) {
    $EnvironmentIds = @()
    if ($Obj.name -ne $ProjectId) {
        foreach ($Environment in $Obj.value) {
                $EnvironmentIds += $Environment
        }
        $ProjectEnvironments.Add($Obj.Name,$EnvironmentIds)
    }
}

# Build json payload
$JsonPayload = @{
    Name = $Tenant.Name
    TenantTags = $Tenant.TenantTags
    SpaceId = $SpaceId
    ProjectEnvironments = $ProjectEnvironments
}

write-host "˅======Updated JSON Between These Lines======˅"
$JsonPayload | ConvertTo-Json
write-host "^======Updated JSON Between These Lines======^"
write-host ""

# Upload Tenant JSON payload
if ($Whatif -eq $false) {
    Invoke-RestMethod -Method Put -Uri "$OctopusURL/api/$($SpaceId)/tenants/$($TenantId)" -Body ($JsonPayload | ConvertTo-Json -Depth 10) -Headers $Header -ContentType "application/json"
    }
else {
    write-host "Dry run detected. Set `$Whatif to `$false to commit changes."
}

write-host "Done"
