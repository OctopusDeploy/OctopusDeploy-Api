$OctopusAPIKey = 'YOUR API KEY'
$ServerUrl = 'https://YOUR INSTANCE NAME/api'
$ProjectId = '' #Project Id to remove

# Add the API key to the headers so we can query the server
$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $OctopusAPIKey)

# First we need a list of all the possible teams to update
$teamUrl = "$ServerUrl/teams?skip=0&take=2147483647"
Write-Host "Getting all the teams from $teamUrl"
$teamResponse = Invoke-RestMethod $teamUrl -Headers $header

#From here on out any requests we make will be updates, let's update the headers to handle that
$header.Add("x-http-method-override", "PUT")

$teamList = $teamResponse.Items

foreach ($team in $teamList)
{
    $projectIds = $team.ProjectIds
    $teamName = $team.Name
    $teamId = $team.Id

    if ($projectIds -match $ProjectId)
    {
        Write-Host "Found ProjectId on $teamName"

        $newProjectIds = @()
        foreach ($arrayId in $projectIds)
        {
            if ($arrayId -ne $ProjectId)
            {
                $newProjectIds += $arrayId
            }
        }

        $team.ProjectIds = $newProjectIds

        $jsonRequest = $team | ConvertTo-Json

        Write-Host "Sending in the request $jsonRequest"

        $teamUpdateUrl = "$ServerUrl/teams/$teamId"
        Write-Host "Updating the team at $teamUpdateUrl"
        Invoke-RestMethod $teamUpdateUrl -Headers $header -Method POST -Body $jsonRequest
    }
}

