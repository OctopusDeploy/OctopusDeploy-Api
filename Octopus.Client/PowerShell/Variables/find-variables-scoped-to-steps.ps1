# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'C:\MyScripts\Octopus.Client\Octopus.Client.dll'

$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXXXXXX' # Get this from your profile
$octopusURI = 'https://octopus.url' # Your Octopus Server address

$projectName = "TestProp"  # Enter project you want to search

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.FindByName($projectName)
$projectVariables = $repository.VariableSets.Get($project.VariableSetId)

foreach ($variables in $projectVariables.Variables)  # For each Variable in referenced project - Return Variable Name & Value
{
    Write-Host "###########################"
    Write-Host "Variable Name = ", $variables.Name
    Write-Host "Variable Value = ", $variables.Value

    $scopeId = $variables.Scope.Values  # Get Scope ID for each Variable

    foreach ($x in $projectVariables.ScopeValues.Actions)  # Compare Scope ID to Scope value
        {
            if ($x.Id -eq $scopeId)  # Return Scope Name if ID matches
            {
                Write-Host "Scoped to Step = ", $x.Name
            }
        }
}
