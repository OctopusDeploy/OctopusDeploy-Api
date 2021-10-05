$OctopusServerUrl = "https://"  #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = "API-"   #PUT YOUR API KEY HERE
$SpaceName = "Default" #PUT THE NAME OF THE SPACE THAT HOUSES THE TENANTS HERE
$spaceId = ((Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/spaces/all" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" }) | Where-Object {$_.Name -eq $spaceName}).Id

$listOfTenants = "TenantOne","TenantTwo" #PUT TENANTS THAT NEED TAGS ADDED TO THEM HERE
$tagstoAdd = "Test Set/Blah","Test Set/Second Blah","Soft Drink Companies/Soft Drink Companies" #PUT TAGSET/TAG HERE TO ADD TO TENANTS ABOVE 

foreach ($tenant in $listOfTenants){
    $tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($spaceid)/tenants?name=$tenant" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" })
    $tenant = $tenantsSearch.Items | Select-Object -First 1
    foreach ($tag in $tagstoAdd){
        $tenant.TenantTags += $tag
    }
   
    Invoke-RestMethod -Method PUT -Uri "$OctopusServerUrl/api/$($spaceid)/tenants/$($tenant.Id)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -body ($tenant | ConvertTo-Json)
    

}
