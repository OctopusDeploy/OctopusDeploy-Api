<#
This script should run from:

- A script step
- That's executed on the Octopus Server
- With a Window size of 1

It'll create an output variable called "MachineNames" Which will have the names of the machines (in octopus, so not the same as $env:computername).

To learn more about the usage of output variables read http://octopusdeploy.com/blog/fun-with-output-variables
#>

##CONFIG##
$Role = "" #Role you want to filter by.
$OctopusAPIkey = "" #API Key to authenticate in Octopus.

##PROCESS##
$OctopusURL = $OctopusParameters['Octopus.Web.BaseUrl']
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$MachineIDs = ($OctopusParameters["Octopus.Environment.MachinesInRole[$Role]"]).Split(',')

$machineNamesArray = @()

foreach ($Id in $MachineIDs){
    $MachineNamesArray += ((Invoke-WebRequest $OctopusURL/api/machines/$id -Headers $header -Method Get).content | ConvertFrom-Json | select -ExpandProperty Name)
}

$MachineNamesString = $machineNamesArray -join ","

#Creating the Output variable
Set-OctopusVariable -name "MachineNames" -value $MachineNamesString