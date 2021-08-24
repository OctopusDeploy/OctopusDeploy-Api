$ErrorActionPreference = "Stop";

# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$libraryVariableSetName = "MyLibraryVariableSet"
$variableName = "MyVariable"
$variableValue = "MyValue"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get repository specific to space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

Write-Host "Looking for library variable set '$libraryVariableSetName'"

$librarySet = $repositoryForSpace.LibraryVariableSets.FindByName($libraryVariableSetName)

# Check to see if something was returned
if ($null -eq $librarySet)
{
    Write-Warning "Library variable not found with name '$libraryVariabelSetName'"
    exit
}

# Get the variableset
$variableSet = $repositoryForSpace.VariableSets.Get($librarySet.VariableSetId)

# Get the variable
($variableSet.Variables | Where-Object {$_.Name -eq $variableName}).Value = $variableValue

# Update
$repositoryForSpace.VariableSets.Modify($variableSet)