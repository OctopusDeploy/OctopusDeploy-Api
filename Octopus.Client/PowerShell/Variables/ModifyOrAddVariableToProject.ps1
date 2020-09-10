# Load octopus.client assembly
Add-Type -Path "c:\octopus.client\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$projectName = "MyProject"
$variable = @{
    Name = "MyVariable"
    Value = "MyValue"
    Type = "String"
    IsSensitive = $false
}

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get project
    [Octopus.Client.Model.ProjectResource]$project = $repositoryForSpace.Projects.FindByName($projectName)

    # Get project variables
    $projectVariables = $repositoryForSpace.VariableSets.Get($project.VariableSetId)

    # Check to see if variable exists
    $variableToUpdate = ($projectVariables.Variables | Where-Object {$_.Name -eq $variable.Name})
    if ($null -eq $variableToUpdate)
    {
        # Create new object
        $variableToUpdate = New-Object Octopus.Client.Model.VariableResource
        $variableToUpdate.Name = $variable.Name
        $variableToUpdate.IsSensitive = $variable.IsSensitive
        $variableToUpdate.Value = $variable.Value
        $variableToUpdate.Type = $variable.Type

        # Add to collection
        $projectVariables.Variables.Add($variableToUpdate)
    }
    else
    {
        # Update the value
        $variableToUpdate.Value = $variable.Value
    }

    # Update the projectvariable
    $repositoryForSpace.VariableSets.Modify($projectVariables)
}
catch
{
    Write-Host $_.Exception.Message
}