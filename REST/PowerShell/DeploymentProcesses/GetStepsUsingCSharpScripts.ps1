$ErrorActionPreference = "Stop" # Ensures the script stops immediately on an error.
$octopusURL = "http://" # Replace with your Octopus Deploy URL
$octopusAPIKey = "API-"     # Replace with your Octopus Deploy API Key

function Get-OctopusItems {
    param(
        [string]$OctopusUri,
        [string]$ApiKey,
        [int]$SkipCount = 0
    )

    $items = @()
    $queryStringPrefix = if ($OctopusUri.Contains("?")) { "&skip=" } else { "?skip=" }
    $headers = @{ "X-Octopus-ApiKey" = $ApiKey }

    $fullUri = "$($OctopusUri)$($queryStringPrefix)$($SkipCount)"
    
    try {
        $resultSet = Invoke-RestMethod -Uri $fullUri -Method GET -Headers $headers -ErrorAction Stop

        if ($null -ne $resultSet.Items) {
            $items += $resultSet.Items

            if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage)) {
                $SkipCount += $resultSet.ItemsPerPage
                $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
            }
        } else {
            return $resultSet
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404 -or 
            ($_.ErrorDetails.Message -and $_.ErrorDetails.Message -like "*Resource is not found*")) {
            Write-Host "  Resource not found: $fullUri" -ForegroundColor DarkYellow
            return @()
        }
        else {
            Write-Host "Error accessing $fullUri : $_" -ForegroundColor Red
            return @()
        }
    }
    return $items
}
if ($octopusURL -eq "https://OctopusServer" -or $octopusAPIKey -eq "API-YourKey") {
    Write-Host "Please update the `$octopusURL` and `$octopusAPIKey` variables with your Octopus Deploy instance details." -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting Octopus Deploy Script Finder..." -ForegroundColor Green

$spaces = Get-OctopusItems -OctopusUri "$octopusURL/api/spaces" -ApiKey $octopusAPIKey

foreach ($space in $spaces) {
    Write-Host "`n--- Space: $($space.Name) ---" -ForegroundColor Cyan

    $projects = Get-OctopusItems -OctopusUri "$octopusURL/api/$($space.Id)/projects" -ApiKey $octopusAPIKey

    foreach ($project in $projects) {
        if ($project.IsVersionControlled -eq $true) {
            continue
        }

        $deploymentProcess = Get-OctopusItems -OctopusUri "$octopusURL/api/$($space.Id)/deploymentProcesses/$($project.DeploymentProcessId)" -ApiKey $octopusAPIKey

        if ($deploymentProcess) {
            foreach ($step in $deploymentProcess.Steps) {
                foreach ($action in $step.Actions) {
                    if ($action.ActionType -eq "Octopus.Script") {
                        $scriptSyntax = $action.Properties.'Octopus.Action.Script.Syntax'
                        if ($scriptSyntax -eq "CSharp") {
                            Write-Host "`n  Project: $($project.Name)" -ForegroundColor Yellow
                            Write-Host "    Step: $($step.Name)" -ForegroundColor Green
                            Write-Host "      Script Type: $scriptSyntax" -ForegroundColor Cyan
                        }
                    }
                }
            }
        }

        $runbooks = Get-OctopusItems -OctopusUri "$octopusURL/api/$($space.Id)/projects/$($project.ID)/runbooks" -ApiKey $octopusAPIKey

        foreach ($runbook in $runbooks) {
            Write-Host "    Checking runbook: $($runbook.Name)" -ForegroundColor Green
            $runbookProcess = Get-OctopusItems -OctopusUri "$octopusURL/api/$($space.Id)/runbookprocesses/$($runbook.RunbookProcessId)" -ApiKey $octopusAPIKey

            if ($runbookProcess) {
                foreach ($step in $runbookProcess.Steps) {
                    foreach ($action in $step.Actions) {
                        if ($action.ActionType -eq "Octopus.Script") {
                            $scriptSyntax = $action.Properties.'Octopus.Action.Script.Syntax'
                            if ($scriptSyntax -eq "CSharp") {
                                Write-Host "`n  Project: $($project.Name) (Runbook: $($runbook.Name))" -ForegroundColor Yellow
                                Write-Host "    Step: $($step.Name)" -ForegroundColor Green
                                Write-Host "      Script Type: $scriptSyntax" -ForegroundColor Cyan
                            }
                        }
                    }
                }
            }
        }
    }
}

Write-Host "`nScript execution complete." -ForegroundColor Green