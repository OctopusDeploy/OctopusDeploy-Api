Param(
    # Developer Parameters
    [switch]$EnableVerbose = $false,
    [switch]$EnableTrace   = $false,

    # Octopus Account Parameters
    [string]$ApiKey     = "#{apiKey}",
    [string]$OctopusUrl = "#{octopusUrl}",

    # Script Parameters
    [int]$Threshold          = 3,
    [string]$EnvironmentId   = "#{Octopus.Environment.Id}",
    [string]$EnvironmentName = "#{Octopus.Environment.Name}",
    [string]$ProjectId       = "#{Octopus.Project.Id}",
    [string]$ProjectName     = "#{Octopus.Project.Name}",
    [string]$ReleaseVersion  = "#{Octopus.Release.Number}"
)

#Requires -Version 5.1

# --- Configuration ---
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($EnableVerbose) { $VerbosePreference = "Continue" }
if ($EnableTrace)   { Set-PSDebug -Trace 1 }

Write-Verbose "=== Starting script: $(Split-Path -Leaf $PSCommandPath) ==="
Write-Verbose "PowerShell Version: $($PSVersionTable.PSVersion)"

# --- Helper Functions ---

function Write-DebugObject {
    <#
    .SYNOPSIS
    Pretty-prints objects as JSON for debugging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,
        
        [int]$Depth = 3,
        
        [string]$Label = "Object"
    )
    process {
        try {
            $json = $InputObject | ConvertTo-Json -Depth $Depth -Compress
            Write-Verbose "$Label (json): $json"
        }
        catch {
            Write-Verbose "$Label (string): $InputObject"
        }
    }
}

function Get-OctopusTasks {
    <#
    .SYNOPSIS
    Retrieves tasks from Octopus Deploy API with filtering.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OctopusUrl,
        
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        
        [Parameter(Mandatory)]
        [string]$EnvironmentId,
        
        [Parameter(Mandatory)]
        [string]$ProjectId,
        
        [scriptblock]$Filter
    )
    
    $uri = "$OctopusUrl/api/tasks?skip=0&take=1000&environment=$EnvironmentId&project=$ProjectId"
    Write-Verbose "HTTP GET $uri"
    
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers
    $tasks = $response.Items
    
    if ($Filter) {
        $tasks = $tasks | Where-Object $Filter
    }
    
    return $tasks
}

function Write-TaskSummary {
    <#
    .SYNOPSIS
    Outputs a summary of tasks with consistent formatting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        $Tasks,
        
        [Parameter(Mandatory)]
        [string]$TaskType,
        
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$ReleaseVersion,
        
        [Parameter(Mandatory)]
        [string]$EnvironmentName
    )
    
    process {
        # Normalize to array
        $taskArray = @($Tasks)
        $count = $taskArray.Count
        
        $context = "$ProjectName release $ReleaseVersion to $EnvironmentName"
        
        if ($count -eq 0) {
            Write-Output "There are 0 $TaskType tasks for $context"
        }
        elseif ($count -eq 1) {
            Write-Output "There is 1 $TaskType task for $context"
            Write-Verbose "$TaskType task:`n$($taskArray[0] | Out-String)"
        }
        else {
            Write-Output "There are $count $TaskType tasks for $context"
            foreach ($task in $taskArray) {
                Write-Verbose "$TaskType task:`n$($task | Out-String)"
            }
        }
    }
}

function Invoke-CancelOctopusTasks {
    <#
    .SYNOPSIS
    Cancels one or more Octopus Deploy tasks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OctopusUrl,
        
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        
        [Parameter(Mandatory)]
        [AllowNull()]
        $Tasks
    )
    
    $taskArray = @($Tasks)
    
    if ($taskArray.Count -eq 0) {
        Write-Verbose "No tasks to cancel"
        return
    }
    
    foreach ($task in $taskArray) {
        $uri = "$OctopusUrl/api/tasks/$($task.Id)/cancel"
        Write-Verbose "HTTP POST $uri"
        Write-Output "Canceling task $($task.Id)"
        
        Invoke-RestMethod -Method Post -Uri $uri -Headers $Headers -UseBasicParsing | Out-Null
    }
}

function Get-TaskCount {
    <#
    .SYNOPSIS
    Safely gets the count of tasks (handles single object or array).
    #>
    param([AllowNull()]$Tasks)
    
    if ($null -eq $Tasks) { return 0 }
    return @($Tasks).Count
}

# --- Main Script Logic ---

try {
    $headers = @{ "X-Octopus-ApiKey" = $ApiKey }
    
    # Fetch cancelled tasks
    $cancelledTasks = Get-OctopusTasks -OctopusUrl $OctopusUrl -Headers $headers `
        -EnvironmentId $EnvironmentId -ProjectId $ProjectId -Filter {
            $_.State -match "Canceled" -and $_.Description -like "*release $ReleaseVersion*"
        }
    
    if (-not $cancelledTasks) {
        Write-Output "No Cancelled tasks found for $ProjectName release $ReleaseVersion to $EnvironmentName. Nothing to action."
        return
    }
    
    # Log cancelled tasks
    Write-TaskSummary -Tasks $cancelledTasks -TaskType "Canceled" `
        -ProjectName $ProjectName -ReleaseVersion $ReleaseVersion -EnvironmentName $EnvironmentName
    
    # Get the most recent cancelled task
    $lastCancelledTask = $cancelledTasks | 
        Sort-Object { [int]($_.Id -replace '\D') } -Descending | 
        Select-Object -First 1
    
    Write-TaskSummary -Tasks $lastCancelledTask -TaskType "LastCanceled" `
        -ProjectName $ProjectName -ReleaseVersion $ReleaseVersion -EnvironmentName $EnvironmentName
    
    # Fetch all tasks since last cancellation
    $allTasks = Get-OctopusTasks -OctopusUrl $OctopusUrl -Headers $headers `
        -EnvironmentId $EnvironmentId -ProjectId $ProjectId -Filter {
            $_.QueueTime -gt $lastCancelledTask.QueueTime -and 
            $_.Description -like "*release $ReleaseVersion*"
        }
    
    Write-TaskSummary -Tasks $allTasks -TaskType "Validate" `
        -ProjectName $ProjectName -ReleaseVersion $ReleaseVersion -EnvironmentName $EnvironmentName
    
    # Get failed/cancelled tasks
    $failedCancelledTasks = Get-OctopusTasks -OctopusUrl $OctopusUrl -Headers $headers `
        -EnvironmentId $EnvironmentId -ProjectId $ProjectId -Filter {
            ($_.State -eq "Failed" -or $_.State -eq "Canceled") -and 
            $_.Description -like "*release $ReleaseVersion*"
        }
    
    Write-TaskSummary -Tasks $failedCancelledTasks -TaskType "Failed/Canceled" `
        -ProjectName $ProjectName -ReleaseVersion $ReleaseVersion -EnvironmentName $EnvironmentName
    
    # Check if threshold is met
    $failureCount = Get-TaskCount -Tasks $failedCancelledTasks
    
    if ($failureCount -lt $Threshold) {
        Write-Output "Number of Failed deployments for $ProjectName release $ReleaseVersion to $EnvironmentName is below the threshold (found $failureCount, threshold is $Threshold). No scheduled tasks will be cancelled."
        return
    }
    
    # Get scheduled tasks to cancel
    $scheduledTasks = $allTasks | Where-Object {
        $_.State -eq "Queued" -and 
        $_.HasBeenPickedUpByProcessor -eq $false -and 
        $_.Name -eq "Deploy" -and 
        $_.Description -like "*release $ReleaseVersion*"
    }
    
    # Cancel scheduled tasks
    if ($scheduledTasks) {
        Write-TaskSummary -Tasks $scheduledTasks -TaskType "Queued" `
            -ProjectName $ProjectName -ReleaseVersion $ReleaseVersion -EnvironmentName $EnvironmentName
        Write-Output "Cancelling all scheduled deployments for $ProjectName release $ReleaseVersion to $EnvironmentName"
        Invoke-CancelOctopusTasks -OctopusUrl $OctopusUrl -Headers $headers -Tasks $scheduledTasks
    }
    else {
        Write-Output "No scheduled deployments found for $ProjectName release $ReleaseVersion to $EnvironmentName. Nothing to cancel."
    }
}
catch {
    Write-Warning "Issues encountered with script: $_"
    
    if ($_.InvocationInfo) {
        Write-Error "At: $($_.InvocationInfo.PositionMessage)"
    }
    
    # Handle HTTP error responses
    if ($_.Exception.Response -is [System.Net.HttpWebResponse]) {
        $response = $_.Exception.Response
        Write-Error "HTTP Status: $([int]$response.StatusCode) $($response.StatusDescription)"
        
        try {
            $stream = $response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Dispose()
                
                if ($body) {
                    Write-Error "Response body: $body"
                }
            }
        }
        catch {
            Write-Verbose "Failed to read response body: $($_.Exception.Message)"
        }
    }
    
    throw
}
finally {
    Write-Verbose "=== Script completed ==="
}