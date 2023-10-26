$octopusUrl = "https://octopusURL" 
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXX" 
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey } 
$spaceId = 'Spaces-XXX' # The Spaces-XXX ID of the space (this can be found in the URL for any page on the space) 
$templateId = "ActionTemplates-XXX" # The ActionTemplates-XXX ID of the step template (this can be found in the URL of the step template, within Library -> Step Templates) 
$update = "" 

$json = Invoke-RestMethod -Method Get -Uri "$($octopusUrl)/api/$($spaceId)/actiontemplates/$templateId" -headers $header 
$latestVersionNumber = $json.version 
write-host "Latest Version number is $($latestVersionNumber)" 


$items = Invoke-RestMethod -Method Get -Uri "$($octopusUrl)/api/$($spaceId)/actiontemplates/$templateId/usage" -headers $header 
Foreach ($item in $items) { 
    if ($item.Version -lt $latestVersionNumber) { 
        $payload = @" 
            {“ActionsToUpdate":[{"ProcessId":"$($item.processid)","ProcessType":"$($item.processtype)","ActionIds”:["$($item.actionid)"],”GitRef":""}],"Overrides":{},"DefaultPropertyValues":{},"Version”:"$($latestVersionNumber)"} 
"@ 
        $update = Invoke-RestMethod -Method Post -Uri "$($octopusUrl)/api/$($spaceId)/actiontemplates/$($templateId)/actionsUpdate" -header $header -body $payload 
        write-host "Updating step template on project $($item.processid) outcome: $($update.Outcome)" 
    } 
}
