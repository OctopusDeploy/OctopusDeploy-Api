# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-ABC123' # Get this from your profile
$octopusURI = 'http://octopus-uri' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

function ClearSensitiveVariables($variableSetId) {
    $vars = $repository.VariableSets.Get($variableSetId)
    foreach ($var in $vars.Variables) {
        if (!$var.IsSensitive) { continue }

        $var.Value = "secret"
        $changed = $true
    }

    $repository.VariableSets.Modify($vars)
}

$libVarSets = $repository.LibraryVariableSets.GetAll()
foreach ($lvs in $libVarSets) {
    ClearSensitiveVariables($lvs.VariableSetId)    
}

$projects = $repository.Projects.GetAll()
foreach ($proj in $projects) {
    ClearSensitiveVariables($proj.VariableSetId)
}
