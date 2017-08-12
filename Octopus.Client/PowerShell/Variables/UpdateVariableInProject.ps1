cls
function UpdateVarInProject {
    Param (
        [Parameter(Mandatory=$true)][string] $UserApiKey,
        [Parameter(Mandatory=$true)][string] $OctopusUrl,
        [Parameter(Mandatory=$true)][string] $ProjectName,
        [Parameter(Mandatory=$true)][string] $VariableToModify,
        [Parameter(Mandatory=$true)][string] $VariableValue,
        [Parameter()][string] $EnvironmentScope,
        [Parameter()][string] $RoleScope,
        [Parameter()][string] $MachineScope,
        [Parameter()][string] $ActionScope
    )
    Process {
        Set-Location "C:\Program Files\Octopus Deploy\Tentacle"
        Add-Type -Path 'Newtonsoft.Json.dll'
        Add-Type -Path 'Octopus.Client.dll'
        $endpoint = New-Object Octopus.Client.OctopusServerEndpoint $OctopusUrl,$UserApiKey
        $repository = New-Object Octopus.Client.OctopusRepository $endpoint
        $project = $repository.Projects.FindByName($ProjectName)
        $variableset = $repository.VariableSets.Get($project.links.variables)
        $variable = $variableset.Variables | ?{$_.name -eq $VariableToModify}
        if ($variable) {
            $variable.Value = $VariableValue
            $Variable.IsSensitive = $false
        }
        else {
            $variable = new-object Octopus.Client.Model.VariableResource
            $variable.Name = $VariableToModify
            $variable.Value = $VariableValue
            $variableset.Variables.Add($variable)
        }
        try {
            if ($EnvironmentScope){
                $variable.Scope.Add([Octopus.Client.Model.ScopeField]::Environment, (New-Object Octopus.Client.Model.ScopeValue($EnvironmentScope)))        
            }
            if ($RoleScope){
                $variable.Scope.Add([Octopus.Client.Model.ScopeField]::Role, (New-Object Octopus.Client.Model.ScopeValue($RoleScope)))        
            }
            if ($MachineScope){
                $variable.Scope.Add([Octopus.Client.Model.ScopeField]::Machine, (New-Object Octopus.Client.Model.ScopeValue($MachineScope)))        
            }
            if ($ActionScope){
                $variable.Scope.Add([Octopus.Client.Model.ScopeField]::Action, (New-Object Octopus.Client.Model.ScopeValue($ActionScope)))        
            }
        }
        catch {}
        if ($repository.VariableSets.Modify($variableset)) {Write-Host "variabe $VariableToModify in $ProjectName successfully modified"}
    }
}
$OctopusUrl = ""
$VarName = "" #Name of the variable to modify
$newvalue = "" # New value to set to the variable
$project = ""
$APIKey = ""
#Example
#UpdateVarInProcess -UserApiKey $APIKey -OctopusUrl $OctopusUrl -ProjectName $project -VariableToModify $VarName -VariableValue $newvalue -EnvironmentScope "Environments-30"
