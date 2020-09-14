# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

$spaceName = "Default" # Name of the Space
$tenantName = "TenantName" # The tenant name
$variableTemplateName = "ProjectTemplateName" # Choose the template Name
$newValue = "NewValue" # Choose a new variable value, assumes same per environment

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $spaceRepository = $client.ForSpace($space)

    # Get Tenant
    $tenant = $spaceRepository.Tenants.FindByName($tenantName)
    
    # Get Tenant Variables
    $variables = $spaceRepository.Tenants.GetVariables($tenant)

    # Loop through each Project Template
    foreach($projectKey in $variables.ProjectVariables.Keys)
    {
        # Get connected project
        $project = $variables.ProjectVariables[$projectKey]
        $projectName = $project.ProjectName
        Write-Host "Working on Project: $projectName ($projectKey)"
        
        # Get Project template ID
        $variableTemplateId = ($project.Templates | Where-Object Name -eq $variableTemplateName | Select-Object -First 1).Id
        if($null -ne $variableTemplateId) {

            Write-Host "Found templateId for Template: $variableTemplateName = $variableTemplateId"

            # Loop through each of the connected environments variables
            foreach($envKey in $project.Variables.Keys) {
            
                # Find variable which matches the current connected environment
                $templateEnvVariableObject = ($project.Variables[$envKey].GetEnumerator() | Where-Object Key -eq $variableTemplateId | Select-Object -ExpandProperty Value -First 1)
            
                # If null / only default value exists, add new value in 
                if($null -eq $templateEnvVariableObject ) {
                    Write-Host "No value found for $variableTemplateName, adding in new Value=$newValue for Environment '$envKey' "
                    $project.Variables[$envKey][$variableTemplateId] = New-Object Octopus.Client.Model.PropertyValueResource $newValue
                } 
                else {

                    # Get Current value
                    $currentValue = $templateEnvVariableObject.Value
                    Write-Host "Found $variableTemplateName in Environment '$envKey' with Value = $currentValue"
        
                    # Set the new value for this connected environment
                    $project.Variables[$envKey][$variableTemplateId] = New-Object Octopus.Client.Model.PropertyValueResource $newValue
                }
            }
        }
        else {
            Write-Host "Couldnt find project template: $variableTemplateName for project $projectName"
        }
    }

    # Update the variables with the new value
    $spaceRepository.Tenants.ModifyVariables($tenant, $variables) | Out-Null
}
catch
{
    Write-Host $_.Exception.Message for
}