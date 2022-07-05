### PowerShell script to get a new user invite using Octopus session cookies.

### Session cookie information (identification and CSRF) can be pulled from the browser by right-clicking an Octopus request in Web Inspector and copying as "Copy as PowerShell"

[String]$OctopusDomain="example.octopus.app"
[String]$OctopusIdentificationTokenName="OctopusIdentificationToken_xxx"
[String]$OctopusIdentificationTokenValue="OCTOPUS_IDENTIFICATION_TOKEN_VALUE"
[String]$OctopusCSRFTokenName="Octopus-Csrf-Token_xxx"
[String]$OctopusCSRFTokenValue="OCTOPUS_CSRF_TOKEN_VALUE"

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.Cookies.Add((New-Object System.Net.Cookie($OctopusIdentificationTokenName, $OctopusIdentificationTokenValue, "/", $OctopusDomain)))
$session.Cookies.Add((New-Object System.Net.Cookie($OctopusCSRFTokenName, $OctopusCSRFTokenValue, "/", $OctopusDomain)))
Invoke-WebRequest -UseBasicParsing -Uri "https://$OctopusDomain/api/users/invitations" `
-Method "POST" `
-WebSession $session `
-Headers @{
  "method"="POST"
  "path"="/api/users/invitations"
  "scheme"="https"
  "accept"="application/json"
  "x-octopus-csrf-token"="$OctopusCSRFTokenValue"
} `
-ContentType "application/json" `
-Body "{`"AddToTeamIds`":[],`"SpaceId`":null}"
