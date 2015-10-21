$headers = @{"X-Octopus-ApiKey"="API-XXXXXXXXXXXXXXXXXXXXXXXXXX"} 

$environments = Invoke-RestMethod "http://octopus.url/api/environments" -Headers $headers -Method Get
$demoEnvironment = $environments.Items | ? { $_.Name -eq "Demo" }

$hostnameOrIpAddress = ""
$port = 10933
$discovered = Invoke-RestMethod "http://octopus.url/api/machines/discover?host=$hostnameOrIpAddress&port=$port" -Headers $headers -Method Get

#$discovered.Name = "MyTentacle" # If you wanted to change the name of the deployment target (default is host name)
$discovered.Roles += "MyRole"
$discovered.EnvironmentIds += $demoEnvironment.Id

$discovered | ConvertTo-Json -Depth 10

Invoke-RestMethod "http://octopus.url/api/machines" -Headers $headers -Method Post -Body ($discovered | ConvertTo-Json -Depth 10)