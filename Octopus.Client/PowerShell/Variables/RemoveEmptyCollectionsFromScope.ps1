$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest;

# Data fix for: http://help.octopusdeploy.com/discussions/problems/51848-variable-with-no-scope

# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path "C:\Program Files\Octopus Deploy\Tentacle\Octopus.Client.dll"

$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXXXXXX' # You can get this from your profile
$octopusURI = 'https://octopus.url' # Your server address
$projectName = "Variables" # Name of the project where you want to update the variable
 
$endpoint = new-object Octopus.Client.OctopusServerEndpoint ($octopusURI, $apikey)
$repository = new-object Octopus.Client.OctopusRepository $endpoint

#Get Project
$project = $repository.Projects.FindByName($projectName)

#Get Project's variable set
$variableset = $repository.VariableSets.Get($project.links.variables)

#Get variable to update    
$variables = $variableset.Variables | Where-Object{$_.Scope -ne $null}

foreach($variable in $variables){
    $keys = @() + $variable.Scope.Keys
    foreach($propertyName in $keys){
        $propertyValue = $variable.Scope[$propertyName];
        if ($propertyValue.Count -eq 0) {
            Write-Host "Removing empty '$propertyName' scope collection from '$($variable.Name)' variable"
            $variable.Scope.Remove($propertyName);
        }
    }
}


#Save variable set
$repository.VariableSets.Modify($variableset)
