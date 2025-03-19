$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-xx"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "MySpace" # Name of the Space
$tenantName = "MyTenant" # The tenant name
$librarySetName = "MyLibrarySet" # Library Variable Set Name
$variableTemplateName = "TestTemplate" # The Library Variable Set template name
$variableScope = @("Production", "Staging") # The variable scope (environment names) of the tenant variable
$newValue = "NewValue" # New variable value for tenant

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get Tenant
$tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
$tenant = $tenantsSearch.Items | Select-Object -First 1

# Get Environments
$validEnvironmentIds = @()
$validEnvironmentNames = @()

$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object { $variableScope -contains $_.Name }
foreach ($environment in $environments) {
    $validEnvironmentIds += $environment.Id
    $validEnvironmentNames += $environment.Name
}

$invalidScopes = Compare-Object $validEnvironmentNames $variableScope
if ($variableScope.Length -ne 0 -and $invalidScopes.Length -ne 0) {
    $invalidEnvironments = $invalidScopes.InputObject | Join-String -Separator ','
    Write-Host "Unable to find environment $invalidEnvironments in space $spaceName"
    exit 0
}

# Get Scoped Common Tenant Variables for tenant
$variables = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/commonvariables" -Headers $header)

# Update value of the tenant variable that matches variableset, template and scope
$newVariables = New-Object Collections.Generic.List[Object]
$oldValue
$updatedVariable

foreach ($commonVariable in $variables.Variables) {
    $value = $commonVariable.Value

    if (($commonVariable.LibraryVariableSetName -eq $librarySetName) -and ($commonVariable.Template.Name -eq $variableTemplateName) -and ((Compare-Object $commonVariable.Scope.EnvironmentIds $validEnvironmentIds).Length -eq 0)) {
        $value = $newValue

        $oldValue = $commonVariable.Value
        $updatedVariable = $commonVariable.Id
    }

    $newVariable = @{
        Id                   = $commonVariable.Id
        LibraryVariableSetId = $commonVariable.LibraryVariableSetId
        TemplateId           = $commonVariable.TemplateId
        Value                = $value
        Scope                = $commonVariable.Scope
    }

    $newVariables.Add($newVariable)
}

# Build json payload
$jsonPayload = @{
    TenantId  = $variables.TenantId
    Variables = $newVariables
}

Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/commonvariables" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)

if (![string]::IsNullOrEmpty($updatedVariable)) { 
    Write-Host "The value of tenant common variable $($updatedVariable) was updated from $($oldValue) to $($newValue)"
}
else {
    Write-Host "No variables were updated"
}