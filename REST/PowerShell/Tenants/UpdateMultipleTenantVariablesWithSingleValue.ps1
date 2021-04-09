$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default" # Name of the Space
$tenantName = "TenantName" # The tenant name
$variableTemplateName = "ProjectTemplateName" # Choose the template Name
$newValue = "NewValue" # Choose a new variable value, assumes same per environment
$NewValueIsBoundToOctopusVariable=$True # Choose $True if the $newValue is an Octopus variable e.g. #{SomeValue}

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
    $variableTemplate = ($project.Templates | Where-Object Name -eq $variableTemplateName | Select-Object -First 1)
    
    
    if($null -ne $variableTemplate) {

        $variableTemplateId = $variableTemplate.Id
        $variableTemplateIsSensitiveControlType = $variableTemplate.DisplaySettings.{Octopus.ControlType} -eq "Sensitive"

        Write-Host "Found templateId for Template: $variableTemplateName = $variableTemplateId"
        $projectConnectedEnvironments = $project.Variables | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name"

        # Loop through each of the connected environments variables
        foreach($envKey in $projectConnectedEnvironments) {
            # Check for Environment project template entry, and add if not present
            if($null -eq $project.Variables.$envKey.$variableTemplateId) {
                $project.Variables.$envKey | Add-Member -MemberType NoteProperty -Name $variableTemplateId -Value $newValue
            }

            # Check sensitive control types differently
            if($variableTemplateIsSensitiveControlType -eq $True) {
                # If $newValue denotes an octopus variable e.g. #{SomeVar}, treat it as if it were text
                if($NewValueIsBoundToOctopusVariable -eq $True) {      
                    Write-Host "Adding in new text value (treating as octopus variable) in Environment '$envKey' for $variableTemplateName"             
                    $project.Variables.$envKey.$variableTemplateId = $newValue
                }    
                else {
                    $newSensitiveValue = [PsCustomObject]@{
                        HasValue = $True
                        NewValue = $newValue
                    }
                    Write-Host "Adding in new sensitive value = '********' in Environment '$envKey' for $variableTemplateName"
                    $project.Variables.$envKey.$variableTemplateId = $newSensitiveValue
                }
            } 
            else {
                Write-Host "Adding in new value = $newValue in Environment '$envKey' for $variableTemplateName"
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