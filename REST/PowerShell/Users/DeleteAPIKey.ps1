##CONFIG
$OctopusURL = "" #Base url of Octopus server
$APIKey = ""#API Key to authenticate to Octopus Server

$UserName = "" #UserName of the user for which the API key will be created. You can check this value from the web portal under Configuration/Users
$APIKeyPurpose = "" #Purpose of the API Key. This is mandatory to identify which API key will be deleted.
##PROCESS

$header = @{ "X-Octopus-ApiKey" = $APIKey }

$body = @{
  Purpose = $APIKeyPurpose
  } | ConvertTo-Json

#Getting all users to filter target user by name
$allUsers = (Invoke-WebRequest "$OctopusURL/api/users/all" -Headers $header -Method Get).content | ConvertFrom-Json

#Getting user that owns API Key that will be deleted
$User = $allUsers | where{$_.username -eq $UserName}

#Getting all API Keys of user
$allAPIKeys = (Invoke-WebRequest "$OctopusURL/api/users/$($user.id)/ApiKeys" -Headers $header -Method Get).content | ConvertFrom-Json | select -ExpandProperty items

#Getting API Key to delete
$APIKeyResource = $allAPIKeys | where{$_.purpose -eq $APIKeyPurpose}

#Deleting API Key
Invoke-WebRequest "$OctopusURL/api/users/$($user.id)/ApiKeys/$($APIKeyResource.id)" -Headers $header -Method Delete

