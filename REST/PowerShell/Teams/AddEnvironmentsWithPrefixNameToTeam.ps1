<#
The goal of this script is to find all the environments which name starts with a certain prefix
and add them to a team's scope

The script wont add environments to the team in a smart way. It'll just clear the current list
of environments and add the ones it could find at runtime with the prefix on their name.
#>

##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

$prefix = "" #all environments  with this prefix will be added to the target team. I.E if your put "Prod", you'll get environments like "Prod_1","Prod_super important" as well as the good old "Production"
$teamName = "" #name of the team to which all environments with the specific prefix will be added.

##PROCESS

$header = @{ "X-Octopus-ApiKey" = $env:OctopusAPIKey }

#Getting environments to add
$Environments = (Invoke-WebRequest $OctopusURL/api/environments/all -Headers $header).content | ConvertFrom-Json
$EnvironmentsToAdd = $Environments | ?{$_.name -like "$prefix*"} #If you want to change the logic to work with a sufix instead of a prefix, this is the line you have to change.

#Getting target team
$teams = (Invoke-WebRequest $OctopusURL/api/teams -Headers $header).content | ConvertFrom-Json | select -ExpandProperty Items
$team  = $teams | ?{$_.name -eq $teamName}

If(!($team)){
    Write-Error "Team not found: $teamname"
    return
}

#Adding environments to team object
$team.EnvironmentIds = $EnvironmentsToAdd.id

#Sending team back to the server after changes
$body = $team | ConvertTo-Json
Invoke-WebRequest "$OctopusURL/api/teams/$($team.id)" -Headers $header -Method Put -Body $body
