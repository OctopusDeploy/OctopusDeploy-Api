###CONFIG###
$OctopusURL = "http://NY-Octopus1" #Octopus Server root URL
$APIKey = "API-ZC3CBI9HG0XBD3CYYBTWM9UWB8" #Octopus API Key

$machineName = "South" #Name of the machine to enable/disable

###PROCESS###
$header = @{ "X-Octopus-ApiKey" = $APIKey }

#Getting all machines
$allmachines = (Invoke-WebRequest $OctopusURL/api/machines/all -Headers $header).content | ConvertFrom-Json

#Filtering machine by name
$machine = $allmachines | ?{$_.name -eq $machineName}

#Setting the "IsDisabled" property
$machine.IsDisabled = $true #Set to $false to disable the machine

#Converting $machine into a JSON blob to PUT is back to the server
$body = $machine | ConvertTo-Json -Depth 4

#Pushing the modified machine to the userver
Invoke-WebRequest ($OctopusURL + $machine.Links.Self) -Method Put -Body $body -Headers $header