###CONFIG###
$APIKey = "***REMOVED***" #API Key to auth agains the Octopus API
$OctopusURL = "***REMOVED***"#Base URL of your Octopus instance.

###PROCESS##
$header = @{ "X-Octopus-ApiKey" = $APIKey }
$MachineID = $OctopusParameters['Octopus.Machine.ID']
$EnvironmentNames = @()

$AllEnvironments = (Invoke-WebRequest $OctopusURL/api/environments/all -Headers $header).content | ConvertFrom-Json

$machine = (Invoke-WebRequest $OctopusURL/api/machines/$MachineID -Headers $header).content | ConvertFrom-Json

foreach ($envID in $machine.environmentIDs){
    $env = $AllEnvironments | ?{$_.id -eq $envID}
    $EnvironmentNames += $env.name    
}

#This variable contains an array with the names of the environments where this machine is on
$EnvironmentNames