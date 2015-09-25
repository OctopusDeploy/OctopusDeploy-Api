Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-WPBDES4YNUBUIILSSJESK9JJ04' 
$octopusURI = 'http://localhost'

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$libraryVariableSet = $repository.LibraryVariableSets.Get("LibraryVariableSets-1");
$variables = $repository.VariableSets.Get($libraryVariableSet.VariableSetId);

$myNewVariable = new-object Octopus.Client.Model.VariableResource
$myNewVariable.Name = "My new variable"
$myNewVariable.Value = "My variable value"
$scopeValue = new-object Octopus.Client.Model.ScopeValue("web-server")
$myNewVariable.Scope.Add([Octopus.Client.Model.ScopeField]::Role, $scopeValue)

$variables.Variables.Add($myNewVariable)
$repository.VariableSets.Modify($variables)
