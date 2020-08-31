$apikey = 'XXXXXX' # Get this from your profile
$OctopusUrl = 'https://OctopusURL/' # Your Octopus Server address
$spaceName = "Default" # Name of the Space
$tenantName = "TenantName" # The tenant name
$variableTemplateName = "ProjectTemplateName" # Choose the template Name
$newValue = "NewValue" # Choose a new variable value, assumes same per environment

# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'Octopus.Client.dll'

# Set up endpoint and Spaces repository
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl, $APIKey
$client = new-object Octopus.Client.OctopusClient $endpoint

# Find Space
$space = $client.ForSystem().Spaces.FindByName($spaceName)
$spaceRepository = $client.ForSpace($space)

# Get Tenant
$tenant = $spaceRepository.Tenants.FindByName($tenantName)
# Get Tenant Variables
$variables = $spaceRepository.Tenants.GetVariables($tenant)

foreach($projectKey in $variables.ProjectVariables.Keys)
{
    $project = $variables.ProjectVariables[$projectKey]
    $projectName = $project.ProjectName
    Write-Host "Working on Project: $projectName ($projectKey)"
    
    $variableTemplateId = ($project.Templates | Where-Object Name -eq $variableTemplateName | Select-Object -First 1).Id
    Write-Host "Found templateId for Template: $variableTemplateName = $variableTemplateId"

    foreach($envKey in $project.Variables.Keys) {
        # Find current value
        $templateEnvVariableObject = ($project.Variables[$envKey].GetEnumerator() | Where-Object Key -eq $variableTemplateId | Select-Object -First 1)
        # If only Default value exists, add new value in 
        if($null -eq $templateEnvVariableObject ) {
            Write-Host "No value found for $variableTemplateName, adding in new Value=$newValue for Environment '$envKey'"
            $project.Variables[$envKey][$variableTemplateId] = New-Object Octopus.Client.Model.PropertyValueResource $newValue
        } 
        else {
            $templateEnvVariable = $templateEnvVariableObject.Value
            $currentValue = $templateEnvVariable.Value
            Write-Host "Found $variableTemplateName in Environment '$envKey' with Value = $currentValue"
        
            # Set the new value for each env
            $project.Variables[$envKey][$variableTemplateId] = New-Object Octopus.Client.Model.PropertyValueResource $newValue
        }
    }
}

# Lastly update the variables with the new value
$spaceRepository.Tenants.ModifyVariables($tenant,$variables)