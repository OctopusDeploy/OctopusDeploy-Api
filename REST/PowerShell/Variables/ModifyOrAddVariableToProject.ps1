$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://OctopusServerURL" # Octopus Server URL
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX" # API key goes here
$projectName = "ProjectName" # Replace with your project name
$spaceName = "Default" # Replace with the name of the space you are working in
$environment = "DevEnv" # Replace with the name of the environment you want to scope the variables to

# Defines header for API call
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get project variables
$projectVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

# Get environment to scope to
$environmentObj = $projectVariables.ScopeValues.Environments | Where { $_.Name -eq $environment } | Select -First 1

# Define values for variable
$variable = @{
    Name = "VariableName" # Replace with a variable name
    Value = "123456" # Replace with a value
    Type = "String"
    IsSensitive = $false
    Scope = @{ 
            Environment = @(
                $environmentObj.Id
                )
            }
}

# Check to see if variable is already present
$variableToUpdate = $projectVariables.Variables | Where-Object {$_.Name -eq $variable.Name}

# If the variable does not exist, create it
if ($null -eq $variableToUpdate)
{
    # Create new object
    $variableToUpdate = New-Object -TypeName PSObject
    $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Name" -Value $variable.Name
    $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Value" -Value $variable.Value
    $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Type" -Value $variable.Type
    $variableToUpdate | Add-Member -MemberType NoteProperty -Name "IsSensitive" -Value $variable.IsSensitive
    $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Scope" -Value $variable.Scope

    # Add to collection
    $projectVariables.Variables += $variableToUpdate

    $projectVariables.Variables
}        

# Update the value
$variableToUpdate.Value = $variable.Value
$variableToUpdate.Scope = $variable.Scope

# Update the collection
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)
