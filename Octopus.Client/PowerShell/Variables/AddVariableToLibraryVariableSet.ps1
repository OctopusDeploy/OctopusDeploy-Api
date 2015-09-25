# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$libraryVariableSetId = "LibraryVariableSets-1" # Get this from /api/libraryvariablesets
$variableName = "Variable name" # Name of the new variable
$variableValue = "Variable value" # Value of the new variable

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$libraryVariableSet = $repository.LibraryVariableSets.Get($libraryVariableSetId);
$variables = $repository.VariableSets.Get($libraryVariableSet.VariableSetId);

$myNewVariable = new-object Octopus.Client.Model.VariableResource
$myNewVariable.Name = $variableName
$myNewVariable.Value = $variableValue

$variables.Variables.Add($myNewVariable)
$repository.VariableSets.Modify($variables)
