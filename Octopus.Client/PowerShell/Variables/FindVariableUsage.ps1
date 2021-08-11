# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$variableToFind = "MyProject.Variable"
$searchDeploymentProcesses = $true
$searchRunbookProcesses = $true
$csvExportPath = "path:\to\CSVFile.csv"

$variableTracking = @()


$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

Write-Host "Looking for usages of variable named $variableToFind in space $($space.Name)"

# Get all projects
$projects = $repositoryForSpace.Projects.GetAll()

# Loop through projects
foreach ($project in $projects)
{
    Write-Host "Checking $($project.Name)"
    
    # Get varaible set
    $projectVariableSet = $repositoryForSpace.VariableSets.Get($project.VariableSetId)
    
    # Find any name matches
    $matchingNamedVariable = $projectVariableSet.Variables | Where-Object {$_.Name -like "*$variableToFind*"}

    if ($null -ne $matchingNamedVariable)
    {
        foreach ($match in $matchingNamedVariable)
        {
            # Create new hashtable
            $result = [pscustomobject]@{
                Project = $project.Name
                MatchType = "Named Project Variable"
                Context = $match.Name
                Property = $null
                AdditionalContext = $match.Value
                Link = $project.Links["Variables"]
            }

            $variableTracking += $result
        }
    }

    # Find any value matches
    $matchingValueVariables = $projectVariableSet.Variables | Where-Object {$_.Value -like "*$variableToFind*"}

    if ($null -ne $matchingValueVariables)
    {
        foreach ($match in $matchingValueVariables)
        {
            $result = [pscustomobject]@{
                Project = $project.Name
                MatchType = "Referenced Project Variable"
                Context = $match.Name
                Property = $null
                AdditionalContext = $match.Value
                Link = $project.Links["Variables"]
            }

            $variableTracking += $result
        }
    }

    if ($searchDeploymentProcesses -eq $true)
    {
        if ($project.IsVersionControlled -ne $true)
        {
            # Get deployment process
            $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

            # Loop through steps
            foreach ($step in $deploymentProcess.Steps)
            {               
                foreach ($action in $step.Actions)
                {
                    foreach ($property in $action.Properties.Keys)
                    {
                        if ($action.Properties[$property].Value -like "*$variableToFind*")
                        {
                            $result = [pscustomobject]@{
                                Project = $project.Name
                                MatchType = "Step"
                                Context = $step.Name
                                Property = $property
                                AdditionalContext = $null
                                Link = "$octopusURL$($project.Links.Web)/deployments/process/steps?actionid=$($action.Id)"
                            }

                            $variableTracking += $result
                        }
                    }
                }
            }
        }
        else
        {
            Write-Host "$($project.Name) is version controlled, skipping searching the deployment process."
        }
    }

    if ($searchRunbookProcesses -eq $true)
    {
        # Get project runbooks
        $runbooks = $repositoryForSpace.Projects.GetAllRunbooks($project)

        # Loop through runbooks
        foreach ($runbook in $runbooks)
        {
            # Get Runbook process
            $runbookProcess = $repositoryForSpace.RunbookProcesses.Get($runbook.RunbookProcessId)

            foreach ($step in $runbookProcess.Steps)
            {
                foreach ($action in $step.Actions)
                {
                    foreach ($proprety in $action.Properties.Keys)
                    {
                        if ($action.Properties[$property].Value -like "*$variableToFind*")
                        {
                            $result = [pscustomobject]@{
                                Project = $project.Name
                                MatchType = "Runbook Step"
                                Context = $runbook.Name
                                Property = $property
                                AdditionalContext = $step.Name
                                Link = "$octopusURL$($project.Links.Web)/operations/runbooks/$($runbook.Id)/process/$($runbook.RunbookProcessId)/steps?actionId=$($action.Id)"
                            }

                            $variableTracking += $result                            
                        }
                    }
                }
            }
        }
    }
}

# De-duplicate
$variableTracking = $variableTracking | Sort-Object -Property * -Unique

if ($variableTracking.Count -gt 0)
{
    Write-Host ""
    Write-Host "Found $($variableTracking.Count) results:"
    $variableTracking

    if(![string]::IsNullOrWhiteSpace($csvExportPath)) 
    {
        Write-Host "Exporting results to CSV file: $csvExportPath"
        $variableTracking | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
}