###CONFIG###
$OctopusURL = "[YOUR URL]" #Octopus Server root URL
$APIKey = "[YOUR API KEY]" #Octopus API Key
$triggersIsDisabled = $true

###PROCESS###
$header = @{ "X-Octopus-ApiKey" = $APIKey }
#Getting all machines
$allprojects = Invoke-RestMethod "$OctopusURL/api/projects/all" -Headers $header

foreach ($project in $allprojects)
{
    $projectId = $project.Id
    $projectName = $project.Name

    Write-Host "Getting all the triggers for $projectName"

    $projectTriggers = Invoke-RestMethod "$OctopusUrl/api/projects/$projectId/triggers" -Headers $header
    foreach ($trigger in $projectTriggers.Items)
    {
        $triggerName = $trigger.Name
        $triggerId = $triggerId
        Write-Host "Setting the disabled flag to $triggersIsDisabled for $triggerName"
        $trigger.IsDisabled = $triggersIsDisabled

        $body = $trigger | ConvertTo-Json -Depth 4
        $disableTriggerHeader = @{
            "x-http-method-override" = "PUT"
            "X-Octopus-ApiKey" = $APIKey
        }

    Invoke-WebRequest ($OctopusUrl + $trigger.Links.Self) -Headers $header -Body $body -Method Put
    
    }
}