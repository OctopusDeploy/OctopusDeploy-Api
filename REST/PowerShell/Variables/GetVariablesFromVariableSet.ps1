##Config
$OctopusAPIkey = "" #Octopus API Key

$OctopusRootURL = "" #Octopus URL. Ex. https://mywebsite.com
$OctopusVirtualDirs = "" #Any virual directory that follows the octopus root url. Ex. /OctopusDeploy

$variableSetName = "Whatever" #Name of the variable set

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

##Process
$VariableSet = (Invoke-WebRequest "$OctopusRootURL$OctopusVirtualDirs/api/libraryvariablesets?contentType=Variables" -Headers $header).content | ConvertFrom-Json | select -ExpandProperty Items | ?{$_.name -eq $variableSetName}

$variables = (Invoke-WebRequest "$OctopusRootURL$($VariableSet.Links.Variables)" -Headers $header).content | ConvertFrom-Json | select -ExpandProperty Variables

$variables #<--- Collection of variables of the variable set
