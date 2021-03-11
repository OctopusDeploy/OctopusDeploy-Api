$OctopusServerUrl = ""
$ApiKey = "API-"
$spaceName = ""
$environmentName = ""
$runbookName = ""
$runbookSnapshotId = "" #leave blank if you'd like to use the published snapshot
$variableName = @() #enter multiple comma separated values if you have multiple prompted variables (e.g. @("promptedvar","promptedvar2"))
$newValue = @() #enter multiple comma separated values if you have multiple prompted variables in the same order as the variable names above (e.g. @("value for promptedvar","value for promptedvar2"))


$spaceId = ((Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/spaces/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}) | Where-Object {$_.Name -eq $spaceName}).Id
$runbookId = ((Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($spaceId)/runbooks/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}) | Where-Object {$_.Name -eq $runbookName}).Id
$environmentId = ((Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($spaceId)/environments/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}) | Where-Object {$_.Name -eq $EnvironmentName}).Id
if ($runbookSnapshotId -eq ""){
$runbookSnapshotId = ((Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($spaceId)/runbooks/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}) | Where-Object {$_.Name -eq $runbookName}).PublishedRunbookSnapshotId
}

#goes and grabs the values of the runbook elements
$elements = Invoke-WebRequest "$($OctopusServerUrl)/api/$($spaceId)/runbooks/$($runbookId)/runbookRuns/preview/$($EnvironmentId)?includeDisabledSteps=true" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}
$elements = $elements | convertfrom-Json

#This finds the element ID(s) you need to put into the jsonbody for the runbook
$elementarray = @() 
foreach ($name in $variablename){
    $element = $elements.Form.Elements | Where-Object { $_.Control.Name -eq $name }
    $elementarray += $element
}

#Create jsonbody to run the runbook with the values.
$jsonbody = @{
    RunBookId = $runbookId
    RunbookSnapshotId = $runbookSnapshotId
    EnvironmentId = $environmentId
    FormValues    = @{    }
} 

#Add the variables to the json.
For ($i=0; $i -lt $elementarray.count; $i++) {
    $temp = $elementarray[$i].Name
    $temp2 = $newvalue[$i]
    $jsonbody.FormValues.Add("$temp","$temp2")
    }

#run the runbook
$jsonbody = $jsonbody |ConvertTo-Json
Invoke-RestMethod -Method "POST" "$($OctopusServerUrl)/api/$($spaceid)/runbookRuns" -body $jsonbody -Headers @{"X-Octopus-ApiKey"="$ApiKey"} -ContentType "application/json"
