$ErrorActionPreference = "Stop";

# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'


# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$searchDeploymentProcesses = $true
$searchRunbookProcesses = $true
$csvExportPath = "path:\to\variable.csv"


# Specify the name of the Library VariableSet to use to find variables usage of
$variableSetVariableUsagesToFind = "My-Variable-Set"

# Search through Project's Deployment Processes?
$searchDeploymentProcesses = $True

# Search through Project's Runbook Processes?
$searchRunbooksProcesses = $True



$variableTracking = @()

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Get first matching variableset record
$libraryVariableSet = $repositoryForSpace.LibraryVariableSets.FindByName($variableSetVariableUsagesToFind)

# Get variables for library variable set
$variableSet = $repositoryForSpace.VariableSets.Get($libraryVariableSet.VariableSetId)
$variables = $variableSet.Variables



Write-Host "Looking for usages of variables from variable set '$variableSetVariableUsagesToFind' in space: '$spaceName'"

# Get all projects
$projects = $repositoryForSpace.Projects.GetAll()

# Loop through projects
foreach ($project in $projects)
{
    Write-Host "Checking project '$($project.Name)'"
    
    # Get project variables
    $projectVariableSet = $repositoryForSpace.VariableSets.Get($project.VariableSetId)
    
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
    if($searchDeploymentProcesses -eq $True -and $project.IsVersionControlled -ne $true) {

        # Get project deployment process
        $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

        # Loop through steps
        foreach($step in $deploymentProcess.Steps)
        {
            foreach ($action in $step.Actions)
            {
                foreach ($property in $action.Properties.Keys)
                {
                    foreach ($variable in $variables)
                    {
                        if ($action.Properties[$property].Value -like "*$($variable.Name)*")
                        {
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
    }

    # Search Runbook processes if configured
    if($searchRunbooksProcesses -eq $True) {
        
        # Get project runbooks
        $runbooks = $repositoryForSpace.Projects.GetAllRunbooks($project)

        # Loop through each runbook
        foreach($runbook in $runbooks)
        {
            # Get runbook process
            $runbookProcess = $repositoryForSpace.RunbookProcesses.Get($runbook.RunbookProcessId)
            
            # Loop through steps
            foreach($step in $runbookProcess.Steps)
            {
                foreach ($action in $step.Actions)
                {
                    foreach ($property in $action.Properties.Keys)
                    {
                        foreach ($variable in $variables)
                        {
                            if ($action.Properties[$property].Value -like "*$($variable.Name)*")
                            {
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
}

# De-dupe
$variableTracking = $variableTracking | Sort-Object -Property * -Unique

if($variableTracking.Count -gt 0) {
    Write-Host ""
    Write-Host "Found $($variableTracking.Count) results:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Host "Exporting results to CSV file: $csvExportPath"
        $variableTracking | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
}