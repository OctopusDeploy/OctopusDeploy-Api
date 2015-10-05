<# 
Add-Type -Path "C:\Program Files\Octopus Deploy\Tentacle\Newtonsoft.Json.dll"
Add-Type -Path "C:\Program Files\Octopus Deploy\Tentacle\Octopus.Client.dll"
 #>

$VarName = "" #Name of the variable to modify
$newvalue = "" # New value to set to the variable
$projectName = "" #name of the project where you want to update the variable

#Connection data
$OctopusURL = ""
$APIKey = ""
 
$endpoint = new-object Octopus.Client.OctopusServerEndpoint ($OctopusURL, $APIKey)
$repository = new-object Octopus.Client.OctopusRepository $endpoint

#Get Project
$project = $repository.Projects.FindByName($projectName)

#Get Project's variable set
$variableset = $repository.VariableSets.Get($project.links.variables)

#Get variable to update    
$variable = $variableset.Variables | ?{$_.name -eq $Varname}

#Update variable
$variable.Value = $newvalue
$Variable.IsSensitive = $false #Set to $true if you want to treat this variable as sensitive 

#Scope examples
#$Variable.Scope.Add([Octopus.platform.Model.Scopefield]::Environment, (New-Object Octopus.Platform.Model.ScopeValue("Environments-1","Environments-2")))
#$Variable.Scope.Add([Octopus.platform.Model.Scopefield]::Role, (New-Object Octopus.Platform.Model.ScopeValue("WebServer","Database")))
#$Variable.Scope.Add([Octopus.platform.Model.Scopefield]::Machine, (New-Object Octopus.Platform.Model.ScopeValue("Machines-1")))
#$Variable.Scope.Add([Octopus.platform.Model.Scopefield]::Action, (New-Object Octopus.Platform.Model.ScopeValue("7455dcd0-c3b3-4ea0-a4c5-58acb6d0a855")))

#Save variable set
$repository.VariableSets.Modify($variableset)
