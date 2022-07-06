### PowerShell script to get a new user invite when using user/pass auth.

[String]$OctopusURL="OCTOPUS_URL"
[String]$OctopusAPIKey = "API_KEY"

$header = @{ 
  "X-Octopus-ApiKey" = $OctopusAPIKey 
  "method"="POST"
  "accept"="application/json"
  }
Invoke-RestMethod -Method "Post" -Uri "$OctopusURL/api/users/invitations" -Headers $header -Body "{`"AddToTeamIds`":[],`"SpaceId`":null}" -ContentType "application/json"
