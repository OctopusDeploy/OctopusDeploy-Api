##Configuration##
$ApiKey = "API-123456" 
$OctopusUrl = "http://myOctopus.com"
$sshTargetName = "TheNameOfMYSSHTarget"
$hostnameOrIpAddress = "127.0.0.1"
$EnvironmentName = "MyEnvironmentName"
$AccountName = "MyAccountName"
$Role = "MyRole"

##Execution##
$headers = @{"X-Octopus-ApiKey" = $ApiKey}

$environment = (Invoke-RestMethod "$OctopusUrl/api/environments/all" -Headers $headers -Method Get) | ? { $_.Name -eq $EnvironmentName } 

$account = (Invoke-RestMethod "$OctopusUrl/api/accounts/all" -Headers $headers -Method Get) | ? { $_.Name -eq $AccountName }

$discovered = Invoke-RestMethod "$OctopusUrl/api/machines/discover?host=$hostnameOrIpAddress&type=Ssh" -Headers $headers -Method Get

$target = @{
            Name = $sshTargetName
            EnvironmentIds = @($environment.Id)
            Endpoint = $discovered.Endpoint
            Roles = @($Role)
          }

$target.Endpoint.AccountId = $account.Id

Invoke-RestMethod "$OctopusUrl/api/machines" -Headers $headers -Method Post -Body ($target | ConvertTo-Json -Depth 2)
