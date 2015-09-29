$headers = @{"X-Octopus-ApiKey"="API-xxxxxxxxxxxxxxxxxxxxxxxxx"} 

$environments = Invoke-RestMethod "http://octopus.url/api/environments/all" -Headers $headers -Method Get
$theEnvironment = $environments | ? { $_.Name -eq "TheEnvironmentName" }

$accounts = Invoke-RestMethod "http://octopus.url/api/accounts/all" -Headers $headers -Method Get
$theAccount = $accounts | ? { $_.Name -eq "TheAccount" }

$hostnameOrIpAddress = "127.0.0.1"
$discovered = Invoke-RestMethod "http://octopus.url/api/machines/discover?host=$hostnameOrIpAddress&type=Ssh" -Headers $headers -Method Get

#$discovered.Name = "MySshTargetName" # If you wanted to change the name of the deployment target (default is host name)
$discovered.Roles += "MyRole"
$discovered.EnvironmentIds += $theEnvironment.Id
$discovered.Endpoint.AccountId = $theAccount.Id


$discovered | ConvertTo-Json -Depth 10

Invoke-RestMethod "http://octopus.url/api/machines" -Headers $headers -Method Post -Body ($discovered | ConvertTo-Json -Depth 10)