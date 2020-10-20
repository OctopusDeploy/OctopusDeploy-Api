$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default" # Name of the Space
$tenantName = "TenantName" # The tenant name
$variableTemplateName = "ProjectTemplateName" # Choose the template Name
$newValue = "NewValue" # Choose a new variable value, assumes same per environment

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Tenant
$tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
$tenant = $tenantsSearch.Items | Select-Object -First 1

# Get Tenant Variables
$variables = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/variables" -Headers $header)

# Get project templates
$projects = $variables.ProjectVariables | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name"

# Loop through each project template
foreach ($projectKey in $projects)
{
    # Get connected project
    $project = $variables.ProjectVariables.$projectKey
    $projectName = $project.ProjectName
    Write-Host "Working on Project: $projectName ($projectKey)"

    # Get Project template ID
    $variableTemplateId = ($project.Templates | Where-Object Name -eq $variableTemplateName | Select-Object -First 1).Id
    
    if($null -ne $variableTemplateId) {

        Write-Host "Found templateId for Template: $variableTemplateName = $variableTemplateId"
        $projectConnectedEnvironments = $project.Variables | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name"

        # Loop through each of the connected environments variables
        foreach($envKey in $projectConnectedEnvironments) {
            
            # Find variable which matches the current connected environment
            $currentValue = $project.Variables.$envKey.$variableTemplateId
            
            # If null / only default value exists, add new value in 
            if($null -eq $currentValue ) {
                Write-Host "No value found for $variableTemplateName, adding in new value = $newValue for Environment '$envKey' "
                $project.Variables.$envKey | Add-Member -MemberType NoteProperty -Name $variableTemplateId -Value $newValue
            } 
            else {
                # Get Current value
                Write-Host "Found $variableTemplateName in Environment '$envKey' with Value = $currentValue"
                # Set the new value for this connected environment
                $project.Variables.$envKey.$variableTemplateId = $newValue
            }        
        }
    }
    else {
        Write-Host "Couldnt find project template: $variableTemplateName for project $projectName"
    }

}
# Update the variables with the new value
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/variables" -Headers $header -Body ($variables | ConvertTo-Json -Depth 10)