# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Specify the Space to search in
$spaceName = "Default"

# Specify the Variable to find, without OctoStache syntax 
# e.g. For #{MyProject.Variable} -> use MyProject.Variable
$variableToFind = "MyProject.Variable"

# Search through Project's Deployment Processes?
$searchDeploymentProcesses = $True

# Search through Project's Runbook Processes?
$searchRunbooksProcesses = $True

# Optional: set a path to export to csv
$csvExportPath = ""

$variableTracking = @()
$octopusURL = $octopusURL.TrimEnd('/')

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}
    
    Write-Host "Looking for usages of variable named $variableToFind in space: '$spaceName'"

    # Get all projects
    $projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

    # Loop through projects
    foreach ($project in $projects)
    {
        Write-Host "Checking project '$($project.Name)'"
        # Get project variables
        $projectVariableSet = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

        # Check to see if variable is named in project variables.
        $matchingNamedVariables = $projectVariableSet.Variables | Where-Object {$_.Name -like "*$variableToFind*"}
        if($null -ne $matchingNamedVariables) {
            foreach($match in $matchingNamedVariables) {
                $result = [pscustomobject]@{
                    Project = $project.Name
                    MatchType = "Named Project Variable"
                    Context = $match.Name
                    Property = $null
                    AdditionalContext = $match.Value
                    Link = "$octopusURL$($project.Links.Web)/variables"
                }
                
                # Add and de-dupe later
                $variableTracking += $result
            }
        }
        
        # Check to see if variable is referenced in other project variable values.
        $matchingValueVariables = $projectVariableSet.Variables | Where-Object {$_.Value -like "*$variableToFind*"}
        if($null -ne $matchingValueVariables) {
            foreach($match in $matchingValueVariables) {
                $result = [pscustomobject]@{
                    Project = $project.Name
                    MatchType = "Referenced Project Variable"
                    Context = $match.Name
                    Property = $null
                    AdditionalContext = $match.Value
                    Link = "$octopusURL$($project.Links.Web)/variables"
                }
                # Add and de-dupe later
                $variableTracking += $result
            }
        }

        # Search Deployment process if enabled
        if($searchDeploymentProcesses -eq $True) {
            # Get project deployment process
            $deploymentProcess = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header)

            # Loop through steps
            foreach($step in $deploymentProcess.Steps)
            {
                $props = $step | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"}
                foreach($prop in $props) 
                {
                    $propName = $prop.Name                
                    $json = $step.$propName | ConvertTo-Json -Compress
                    if($null -ne $json -and ($json -like "*$variableToFind*")) {
                        $result = [pscustomobject]@{
                            Project = $project.Name
                            MatchType= "Step"
                            Context = $step.Name
                            Property = $propName
                            AdditionalContext = $null
                            Link = "$octopusURL$($project.Links.Web)/deployments/process/steps?actionId=$($step.Actions[0].Id)"
                        }
                        # Add and de-dupe later
                        $variableTracking += $result
                    }
                }
            }
        }

        # Search Runbook processes if enabled
        if($searchRunbooksProcesses -eq $True) {
            
            # Get project runbooks
            $runbooks = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?skip=0&take=5000" -Headers $header)

            # Loop through each runbook
            foreach($runbook in $runbooks.Items)
            {
                # Get runbook process
                $runbookProcess = (Invoke-RestMethod -Method Get -Uri "$octopusURL$($runbook.Links.RunbookProcesses)" -Headers $header)
                
                # Loop through steps
                foreach($step in $runbookProcess.Steps)
                {
                    $props = $step | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"}
                    foreach($prop in $props) 
                    {
                        $propName = $prop.Name                
                        $json = $step.$propName | ConvertTo-Json -Compress
                        if($null -ne $json -and ($json -like "*$variableToFind*")) {
                            $result = [pscustomobject]@{
                                Project = $project.Name
                                MatchType = "Runbook Step"
                                Context = $runbook.Name
                                Property = $propName
                                AdditionalContext = $step.Name
                                Link = "$octopusURL$($project.Links.Web)/operations/runbooks/$($runbook.Id)/process/$($runbook.RunbookProcessId)/steps?actionId=$($step.Actions[0].Id)"
                            }
                            # Add and de-dupe later
                            $variableTracking += $result
                        }
                    }
                }
            }
        }
    }
    
    # De-dupe
    $variableTracking = $variableTracking | Sort-Object -Property * -Unique

    if($variableTracking.Count -gt 0) {
        Write-Host ""
        Write-Host "Found $($variableTracking.Count) results:"
        $variableTracking
        if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
            Write-Host "Exporting results to CSV file: $csvExportPath"
            $variableTracking | Export-Csv -Path $csvExportPath -NoTypeInformation
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}