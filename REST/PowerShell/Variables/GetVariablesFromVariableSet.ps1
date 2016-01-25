##Config
$OctopusAPIkey = ""#Octopus API Key

$OctopusURL = ""#Octopus URL

$variableSetName = "Whatever" #Name of the variable set

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

##Process
$VariableSet = (Invoke-WebRequest "$OctopusURL/api/libraryvariablesets?contentType=Variables" -Headers $header).content | ConvertFrom-Json | select -ExpandProperty Items | ?{$_.name -eq $variableSetName}

$variables = (Invoke-WebRequest "$OctopusURL/$($VariableSet.Links.Variables)" -Headers $header).content | ConvertFrom-Json | select -ExpandProperty Variables

$variables #<--- Collection of variables of the variable set