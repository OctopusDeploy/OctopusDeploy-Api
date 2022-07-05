### PowerShell script to get a new user invite when using user/pass auth.

[String]$OctopusDomain="example.octopus.app"
[String]$octopusAPIKey = "API-KEY"

Invoke-WebRequest -UseBasicParsing -Uri "https://$OctopusDomain/api/users/invitations" `
-Method "POST" `
-WebSession $session `
-Headers @{
  "method"="POST"
  "path"="/api/users/invitations"
  "scheme"="https"
  "accept"="application/json"
  "X-Octopus-ApiKey" = $octopusAPIKey
} `
-ContentType "application/json" `
-Body "{`"AddToTeamIds`":[],`"SpaceId`":null}"
