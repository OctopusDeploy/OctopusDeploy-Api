##CONFIG
$OctopusURL = "" #Base url of Octopus server
$APIKey = "" #API Key to authenticate to Octopus Server

$UserName = "" #UserName of the user for which the API key will be created. You can check this value from the web portal under Configuration/Users
$APIKeyPurpose = "" #Purpose of the API Key. This field is mandatory.

##PROCESS
$header = @{ "X-Octopus-ApiKey" = $APIKey }

$body = @{
  Purpose = $APIKeyPurpose
  } | ConvertTo-Json


#Getting all users to filter target user by name
$allUsers = (Invoke-WebRequest "$OctopusURL/api/users/all" -Headers $header -Method Get).content | ConvertFrom-Json

#Getting user that owns API Key that will be deleted
$User = $allUsers | where{$_.username -eq $UserName}

#Creating API Key
$CreateAPIKeyResponse = (Invoke-WebRequest "$OctopusURL/api/users/$($User.id)/apikeys" -Method Post -Headers $header -Body $body -Verbose).content | ConvertFrom-Json

#Printing new API Key
Write-output "API Key created: $($CreateAPIKeyResponse.apikey)"