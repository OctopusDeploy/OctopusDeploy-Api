$OctopusAPIkey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX"#Octopus API Key

$OctopusURL = "https://octopus.url"#Octopus URL

$project = "Projects-31" #Name of the variable set

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

##Process
$tenantVariables = (Invoke-WebRequest -UseBasicParsing "$OctopusURL/api/tenantvariables/all?$project" -Headers $header).content #| ConvertFrom-Json

$tenantVariables
