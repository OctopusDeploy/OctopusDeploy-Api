$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Specify the Space to search in
$spaceName = "Default"

# Specify the name of the Library VariableSet to use to find variables usage of
$variableSetVariableUsagesToFind = "My-Variable-Set"

# Search through Project's Deployment Processes?
$searchDeploymentProcesses = $True

# Search through Project's Runbook Processes?
$searchRunbooksProcesses = $True

# Optional: set a path to export to csv
$csvExportPath = ""

$variableTracking = @()
$octopusURL = $octopusURL.TrimEnd('/')

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get first matching variableset record
$libraryVariableSet = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header) | Where-Object {$_.Name -eq $variableSetVariableUsagesToFind} | Select-Object -First 1

# Get variables for library variable set
$variableSet  = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($libraryVariableSet.VariableSetId)" -Headers $header)
$variables = $variableSet.Variables

Write-Host "Looking for usages of variables from variable set '$variableSetVariableUsagesToFind' in space: '$spaceName'"

# Get all projects
$projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projects)
{
    Write-Host "Checking project '$($project.Name)'"
    
    # Get project variables
    $projectVariableSet = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header
    
    # Check to see if there are any project variable values that reference any of the library set variables.
    foreach($variable in $variables) {
        
        $matchingValueVariables = $projectVariableSet.Variables | Where-Object {$_.Value -like "*$($variable.Name)*"}

        if($null -ne $matchingValueVariables) {
            foreach($match in $matchingValueVariables) {
                $result = [pscustomobject]@{
                    Project = $project.Name
                    MatchType = "Referenced Project Variable"
                    VariableSetVariable = $variable.Name
                    Context = $match.Name
                    AdditionalContext = $match.Value
                    Property = $null
                    Link = "$octopusURL$($project.Links.Web)/variables"
                }
                # Add and de-dupe later
                $variableTracking += $result
            }
        }
    }

    # Search Deployment process if configured
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
                
                # Check to see if any of the variableset variables are referenced in this step's properties
                foreach($variable in $variables)
                {
                    if($null -ne $json -and ($json -like "*$($variable.Name)*")) {
                        $result = [pscustomobject]@{
                            Project = $project.Name
                            MatchType= "Step"
                            VariableSetVariable = $variable.Name
                            Context = $step.Name
                            AdditionalContext = $null
                            Property = $propName
                            Link = "$octopusURL$($project.Links.Web)/deployments/process/steps?actionId=$($step.Actions[0].Id)"
                        }
                        # Add and de-dupe later
                        $variableTracking += $result
                    }
                }
            }
        }
    }

    # Search Runbook processes if configured
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
                    
                    # Check to see if any of the variableset variables are referenced in this runbook step's properties
                    foreach($variable in $variables)
                    {
                        if($null -ne $json -and ($json -like "*$($variable.Name)*")) {
                            $result = [pscustomobject]@{
                                Project = $project.Name
                                MatchType= "Runbook Step"
                                VariableSetVariable = $variable.Name
                                Context = $runbook.Name
                                AdditionalContext = $step.Name
                                Property = $propName
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
}

# De-dupe
$variableTracking = @($variableTracking | Sort-Object -Property * -Unique)

if($variableTracking.Count -gt 0) {
    Write-Host ""
    Write-Host "Found $($variableTracking.Count) results:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Host "Exporting results to CSV file: $csvExportPath"
        $variableTracking | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
}