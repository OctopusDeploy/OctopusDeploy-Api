#This script will throw an error if at least 1 of the roles in $MandatoryRoles is missing on the machine

$MandatoryRoles = "Octopus2","Octopus1" #List of roles that the Machine should have

function Validate-MandatoryMachineRoles ($MandatoryRoles){

    $RolesInMachineSplit = $OctopusParameters['Octopus.Machine.Roles'].Split(',')
    $MachineName = $($OctopusParameters['Octopus.Machine.Name'])
    
    $MissingRoles = @()

    foreach($MandatoryRole in $MandatoryRoles){
        If($MandatoryRole -notin $RolesInMachineSplit){
            $MissingRoles += $MandatoryRole
        }
    }

    If($MissingRoles.Count -ne 0){
        Write-Error "The following mandatory roles were not found in [$MachineName]: $MissingRoles"
    }
}

Validate-MandatoryMachineRoles -MandatoryRoles $MandatoryRoles