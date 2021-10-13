$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
# Optional space filter
$spaceName = "Default"
# Optional project filter
$projectName = ""
# Optional runbook filter
$runbookName = ""

# Max runbook run qty per environment to keep
$runbookMaxRetentionRunPerEnvironment = 5

# Get spaces
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces/all" -Headers $header 
if (![string]::IsNullOrWhitespace($spaceName)) {
    Write-Output "Filtering spaces to just $spaceName"
    $spaces = $spaces | Where-Object { $_.Name -ieq $spaceName }
}
Write-Output "Space Count: $($spaces.Length)"
foreach ($space in $spaces) {
    Write-Output "Working on space $($space.Name)"

    $projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header     
    if (![string]::IsNullOrWhitespace($projectName)) {
        Write-Output "Filtering projects to just $projectName"
        $projects = $projects | Where-Object { $_.Name -ieq $projectName }
    }
    Write-Output "Project Count: $($projects.Length)"

    foreach ($project in $projects) {
        Write-Output "Working on project $($project.Name)"
        
        $projectRunbooks = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks" -Headers $header         
        if (![string]::IsNullOrWhitespace($runbookName)) {
            Write-Output "Filtering runbooks to just $runbookName"
            $runbooks = $projectRunbooks.Items | Where-Object { $_.Name -ieq $runbookName }
        }else {
            $runbooks = $projectRunbooks.Items
        }
        Write-Output "Runbook Count: $($runbooks.Length)"
        
        foreach ($runbook in $runbooks) {
            Write-Output "Working on runbook $($runbook.Name)"
            $currentRetentionQuantityToKeep = $runbook.RunRetentionPolicy.QuantityToKeep
            
            if($currentRetentionQuantityToKeep -gt $runbookMaxRetentionRunPerEnvironment) {
                Write-Output "Runbook '$($runbook.Name)' ($($runbook.Id)) has a retention run policy to keep of: $($currentRetentionQuantityToKeep) which is greater than $($runbookMaxRetentionRunPerEnvironment)"
                $runbook.RunRetentionPolicy.QuantityToKeep = $runbookMaxRetentionRunPerEnvironment
                Write-Output "Updating runbook run quantity to keep for '$($runbook.Name)'' ($($runbook.Id)) to $runbookMaxRetentionRunPerEnvironment"

                $runbookResponse = Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/runbooks/$($runbook.Id)" -Body ($runbook | ConvertTo-Json -Depth 10) -Headers $header
                if($runbookResponse.RunRetentionPolicy.QuantityToKeep -ne $runbookMaxRetentionRunPerEnvironment) {
                    throw "Update for '$($runbook.Name)' ($($runbook.Id)) doesnt look like it worked. QtyToKeep is: $($runbookResponse.RunRetentionPolicy.QuantityToKeep)"
                }
            }
        }
    }
}
