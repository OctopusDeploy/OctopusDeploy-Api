### PowerShell script to get a new user invite when using user/pass auth.

[String]$OctopusURL="https://example.octopus.app"
[String]$octopusAPIKey = "API-KEY"

Invoke-WebRequest -UseBasicParsing -Uri "$OctopusURL/api/users/invitations" `
-Method "POST" `
-Headers @{
  "method"="POST"
  "path"="/api/users/invitations"
  "scheme"="https"
  "accept"="application/json"
  "X-Octopus-ApiKey" = $octopusAPIKey
} `
-ContentType "application/json" `
-Body "{`"AddToTeamIds`":[],`"SpaceId`":null}"
