$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-xx"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "MySpace" # Name of the Space
$tenantName = "MyTenant" # The tenant name
$librarySetName = "MyLibrarySet" # Library Variable Set Name
$variableTemplateName = "TestTemplate" # The Library Variable Set template name
$newValue = "NewValue" # New variable value for tenant

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get Tenant
$tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
$tenant = $tenantsSearch.Items | Select-Object -First 1

# Get Library Set Id
$librarySet = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header) | Where-Object { $_.Name -eq $librarySetName }
$librarySetId = $librarySet.Id

# Get Tenant common variables
$variables = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/variables" -Headers $header)
$libraryVariableSets = $variables.LibraryVariables

# Get variable Id from template
$variableValueId = $null 
foreach ($template in $libraryVariableSets.$librarySetId.Templates) {
    if ($template.Name -eq $variableTemplateName) {
        $variableValueId = $template.Id
    }
}

# Set variable value on tenant using variable Id from template
$libraryVariableSets.$librarySetId.Variables.$variableValueId = $newValue

# Put modified JSON to update tenant
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/variables" -Headers $header -Body ($variables | ConvertTo-Json -Depth 10)
