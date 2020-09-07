# Octopus URL
$octopusURL = "https://octopusurl"

# Octopus API Key
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Space Name
$spaceName = "Default"

# Canonical TagSet Name. 
# e.g. "AWS Region/California" See: https://octopus.com/docs/deployment-patterns/multi-tenant-deployments/tenant-tags#TenantTags-Referencingtenanttags
$canonicalTagSet = "Tag Set Name/Tag Name"

$matchingTenantIds = @()

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Filter tenants by tag set
    $tenants = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/tag-test?tags=$canonicalTagSet" -Headers $header)

    #$tenants
    $tenantProperties = Get-Member -InputObject $tenants -MemberType NoteProperty
    #$props
    foreach ($tenantProp in $tenantProperties)
    {           
        $tenantId = $tenantProp.Name
        $tenant = $tenants | Select-Object -ExpandProperty $tenantProp.Name
        if($tenant.IsMatched -eq $True) {
            $matchingTenantIds += $tenantId
        }       
    }
}
catch
{
    Write-Host $_.Exception.Message
}

Write-Host "Tenants found matching canonical tagset of $($canonicalTagSet):"
$matchingTenantIds