<#
.SYNOPSIS
    Reports which workers (and worker pools) were leased by Octopus deployment and runbook tasks,
    with project/environment association and optional grouped summaries.

.DESCRIPTION
    Improvements over REST/PowerShell/Workers/GetWorkersUsedInTasks.ps1:
      * Reads the plain-text raw task log (/tasks/{id}/raw) instead of the verbose JSON details tree,
        which is much less data to download and deserialise. -LogSource Details falls back to the old method.
      * Fetches task logs in parallel on PowerShell 7+ (-ThrottleLimit), sequentially on Windows PowerShell 5.1.
      * Parses "Leased worker <name> from pool <pool> (lease ...)" with a regex, so worker and pool names
        containing spaces are handled, and the whole log tree is searched (not just two levels deep).
      * Resolves the project and environment for every task.
      * Writes real CSV (Export-Csv) plus an optional grouped summary.
      * Server-side filtering by task type, state, completed date range and project.

.PARAMETER GroupBy
    None, Project, Worker, WorkerPool, ProjectAndWorker or ProjectAndPool. Controls the summary CSV
    and the summary written to the pipeline. The detail CSV is always written.

.PARAMETER MaxTasks
    Maximum number of tasks to inspect (applied per project when -ProjectName is used). Tasks are
    returned newest first.

.EXAMPLE
    # Edit the CONFIGURATION section at the top, then simply run:
    ./Get-WorkerUsageFromTasks.ps1

.EXAMPLE
    $env:OCTOPUS_API_KEY = 'API-XXXX'
    ./Get-WorkerUsageFromTasks.ps1 -OctopusUrl https://my.octopus.app -GroupBy Project

.EXAMPLE
    ./Get-WorkerUsageFromTasks.ps1 -OctopusUrl https://my.octopus.app -ApiKey $key -SpaceName "Default" `
        -From (Get-Date).AddDays(-30) -States Success,Failed -GroupBy Worker -MaxTasks 2000 -ThrottleLimit 12

.EXAMPLE
    ./Get-WorkerUsageFromTasks.ps1 -OctopusUrl https://my.octopus.app -ProjectName "Web API","Billing" -GroupBy ProjectAndWorker
#>

#Requires -Version 5.1
# =============================================================================================
#  CONFIGURATION - edit these values, then just run the script.
#  Any of them can still be overridden on the command line, e.g. -GroupBy Worker
#  Full help is at the bottom of this file (Get-Help ./Get-WorkerUsageFromTasks.ps1 -Full).
# =============================================================================================
[CmdletBinding()]
param(
    # Octopus server URL, e.g. "https://my.octopus.app"
    [string] $OctopusUrl = "https://my.octopus.url",

    # API key. Leave empty to use the OCTOPUS_API_KEY environment variable instead.
    [string] $ApiKey = "",

    # Name of the space to search
    [string] $SpaceName = "Default",

    # Maximum number of tasks to inspect, newest first (per project when ProjectName is set)
    [ValidateRange(1, 1000000)]
    [int] $MaxTasks = 500,

    # Task types to include: "Deploy", "RunbookRun"
    [ValidateSet("Deploy", "RunbookRun")]
    [string[]] $TaskTypes = @("Deploy", "RunbookRun"),

    # Task states to include, e.g. @("Success", "Failed"). Empty = all states.
    [ValidateSet("Success", "Failed", "Canceled", "TimedOut", "Executing", "Cancelling", "Queued")]
    [string[]] $States = @(),

    # Only tasks completed on/after this date, e.g. (Get-Date).AddDays(-30) or [datetime]"2026-09-01". $null = no limit.
    [Nullable[datetime]] $From = $null,

    # Only tasks completed on/before this date. $null = no limit.
    [Nullable[datetime]] $To = $null,

    # Limit to these projects, e.g. @("Web API", "Billing"). Empty = all projects.
    [string[]] $ProjectName = @(),

    # Summary grouping: "None", "Project", "Worker", "WorkerPool", "ProjectAndWorker", "ProjectAndPool"
    [ValidateSet("None", "Project", "Worker", "WorkerPool", "ProjectAndWorker", "ProjectAndPool")]
    [string] $GroupBy = "Project",

    # Folder the CSV files are written to
    [string] $OutputPath = ".",

    # Number of task logs fetched at once (PowerShell 7+ only)
    [ValidateRange(1, 64)]
    [int] $ThrottleLimit = 8,

    # Tasks requested per page from the API
    [ValidateRange(1, 1000)]
    [int] $PageSize = 100,

    # "Raw" (fast, plain-text log) or "Details" (verbose JSON log, as the original script used)
    [ValidateSet("Raw", "Details")]
    [string] $LogSource = "Raw"
)
# =============================================================================================

$ErrorActionPreference = "Stop"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $env:OCTOPUS_API_KEY }
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "No API key supplied. Set `$ApiKey in the configuration section, pass -ApiKey, or set the OCTOPUS_API_KEY environment variable."
}
if ([string]::IsNullOrWhiteSpace($OctopusUrl) -or $OctopusUrl -eq "https://my.octopus.url") {
    throw "Set `$OctopusUrl in the configuration section at the top of the script (or pass -OctopusUrl)."
}

# Accept a URL copied from the browser (e.g. https://x.octopus.app/app#/Spaces-1/projects) or one ending in /api.
$OctopusUrl = ($OctopusUrl.Trim() -replace '#.*$', '').TrimEnd('/')
$OctopusUrl = $OctopusUrl -replace '(?i)/(app|api)$', ''
$header = @{ "X-Octopus-ApiKey" = $ApiKey }

function Invoke-Octopus([string] $Path) {
    $uri = "$OctopusUrl$Path"
    try {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get
    }
    catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        $hint = switch ($status) {
            401     { " Check the API key." }
            403     { " The API key's user lacks permission for this resource." }
            404     { " Check that the server URL (currently '$OctopusUrl') is the root of your Octopus instance, with no extra path." }
            default { "" }
        }
        throw "GET $uri failed ($(if ($status) { "HTTP $status" } else { $_.Exception.Message })).$hint"
    }
}

# Reads every item from a paged collection endpoint (avoids relying on the /all endpoints).
function Get-OctopusCollection([string] $Path, [int] $Take = 1000) {
    $separator = if ($Path.Contains('?')) { '&' } else { '?' }
    $skip = 0
    do {
        $page  = Invoke-Octopus "$Path$($separator)skip=$skip&take=$Take"
        $items = @($page.Items)
        $items
        $skip += $items.Count
    } while ($items.Count -gt 0 -and $skip -lt $page.TotalResults)
}

function Format-Date($Value) {
    if ($null -eq $Value -or $Value -eq '') { return $null }
    ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss")
}

function Join-Distinct($Values) {
    (@($Values) | Where-Object { $_ } | Sort-Object -Unique) -join "; "
}

# --- Space and lookup tables (fetched once, instead of per task) --------------------------------
$space = Get-OctopusCollection "/api/spaces?partialName=$([uri]::EscapeDataString($SpaceName))" | Where-Object { $_.Name -eq $SpaceName }
if (-not $space) { throw "Space '$SpaceName' not found." }
$spaceId = $space.Id

$projectNames = @{}
foreach ($p in (Get-OctopusCollection "/api/$spaceId/projects")) { $projectNames[$p.Id] = $p.Name }

$environmentNames = @{}
foreach ($e in (Get-OctopusCollection "/api/$spaceId/environments")) { $environmentNames[$e.Id] = $e.Name }

# --- Optional project filter ------------------------------------------------------------------
$projectFilterIds = @($null)   # $null = no project filter
if ($ProjectName) {
    $projectFilterIds = @(foreach ($name in $ProjectName) {
        $id = $projectNames.Keys | Where-Object { $projectNames[$_] -eq $name } | Select-Object -First 1
        if ($id) { $id } else { Write-Warning "Project '$name' not found in space '$SpaceName'; skipping." }
    })
    if ($projectFilterIds.Count -eq 0) { throw "None of the requested projects were found." }
}

# --- Collect tasks (cheap list calls, filtered server side) -----------------------------------
$baseQuery = @(
    "spaces=$spaceId",
    "includeSystem=false",
    "name=$($TaskTypes -join ',')"
)
if ($States) { $baseQuery += "states=$($States -join ',')" }
if ($From) { $baseQuery += "fromCompletedDate=$([uri]::EscapeDataString(([datetime]$From).ToUniversalTime().ToString('o')))" }
if ($To)   { $baseQuery += "toCompletedDate=$([uri]::EscapeDataString(([datetime]$To).ToUniversalTime().ToString('o')))" }

$tasks = [System.Collections.Generic.List[object]]::new()
foreach ($projectId in $projectFilterIds) {
    $query = $baseQuery
    if ($projectId) { $query += "project=$projectId" }

    $skip = 0
    while ($skip -lt $MaxTasks) {
        $take = [Math]::Min($PageSize, $MaxTasks - $skip)
        $page = Invoke-Octopus "/api/tasks?$($query -join '&')&skip=$skip&take=$take"
        $items = @($page.Items)
        if ($items.Count -eq 0) { break }

        foreach ($item in $items) { $tasks.Add($item) }
        $skip += $items.Count
        Write-Host "Listed $($tasks.Count) task(s)..."
        if ($skip -ge $page.TotalResults) { break }
    }
}

if ($tasks.Count -eq 0) {
    Write-Warning "No tasks matched the filters."
    return
}

# --- Per-task processing (runs in parallel on PS 7+) ------------------------------------------
# Kept as a string so it can be rebuilt inside ForEach-Object -Parallel runspaces.
$processTaskText = @'
param($Task, $Ctx)

$h   = $Ctx.Header
$api = "$($Ctx.Url)/api/$($Ctx.SpaceId)"

try {
    if ($Ctx.LogSource -eq "Raw") {
        $log = Invoke-RestMethod -Uri "$api/tasks/$($Task.Id)/raw" -Headers $h -Method Get
        if ($log -is [byte[]]) { $log = [System.Text.Encoding]::UTF8.GetString($log) }
    }
    else {
        $details = Invoke-RestMethod -Uri "$api/tasks/$($Task.Id)/details?verbose=true" -Headers $h -Method Get
        $sb    = [System.Text.StringBuilder]::new()
        $stack = [System.Collections.Generic.Stack[object]]::new()
        foreach ($node in $details.ActivityLogs) { $stack.Push($node) }
        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            foreach ($element in $node.LogElements) { [void]$sb.AppendLine($element.MessageText) }
            foreach ($child in $node.Children) { $stack.Push($child) }
        }
        $log = $sb.ToString()
    }

    $pattern = '(?m)Leased worker (?<Worker>.+?) from pool (?<Pool>.+?)(?: \(lease (?<Lease>[^)\r\n]+)\))?\.?\r?$'
    $found = [regex]::Matches([string]$log, $pattern)
    if ($found.Count -eq 0) { return }

    # Project/environment: use the task fields where present, otherwise ask the deployment / runbook run.
    $projectId     = $Task.ProjectId
    $environmentId = $Task.EnvironmentId
    if (-not $projectId) {
        if ($Task.Arguments.DeploymentId) {
            $source = Invoke-RestMethod -Uri "$api/deployments/$($Task.Arguments.DeploymentId)" -Headers $h -Method Get
        }
        elseif ($Task.Arguments.RunbookRunId) {
            $source = Invoke-RestMethod -Uri "$api/runbookRuns/$($Task.Arguments.RunbookRunId)" -Headers $h -Method Get
        }
        if ($source) {
            $projectId     = $source.ProjectId
            $environmentId = $source.EnvironmentId
        }
    }

    $usedAt = if ($Task.CompletedTime) { $Task.CompletedTime } elseif ($Task.StartTime) { $Task.StartTime } else { $Task.QueueTime }

    $found |
        ForEach-Object { [pscustomobject]@{ Worker = $_.Groups['Worker'].Value.Trim(); Pool = $_.Groups['Pool'].Value.Trim() } } |
        Group-Object Worker, Pool |
        ForEach-Object {
            [pscustomobject]@{
                TaskId          = $Task.Id
                TaskType        = $Task.Name
                TaskDescription = $Task.Description
                State           = $Task.State
                ProjectId       = $projectId
                EnvironmentId   = $environmentId
                QueueTime       = $Task.QueueTime
                StartTime       = $Task.StartTime
                CompletedTime   = $Task.CompletedTime
                UsedAt          = $usedAt
                WorkerName      = $_.Group[0].Worker
                WorkerPool      = $_.Group[0].Pool
                LeaseCount      = $_.Count
            }
        }
}
catch {
    Write-Warning "Task $($Task.Id): $($_.Exception.Message)"
}
'@

$ctx = @{
    Url       = $OctopusUrl
    SpaceId   = $spaceId
    Header    = $header
    LogSource = $LogSource
}

Write-Host "Reading logs for $($tasks.Count) task(s) using the '$LogSource' log source..."

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $rawRows = $tasks | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $sb = [scriptblock]::Create($using:processTaskText)
        & $sb $_ $using:ctx
    }
}
else {
    Write-Host "PowerShell $($PSVersionTable.PSVersion) detected; running sequentially (use PowerShell 7+ for parallel fetching)."
    $sb = [scriptblock]::Create($processTaskText)
    $i = 0
    $rawRows = foreach ($task in $tasks) {
        $i++
        Write-Progress -Activity "Reading task logs" -Status "$i / $($tasks.Count): $($task.Id)" -PercentComplete (100 * $i / $tasks.Count)
        & $sb $task $ctx
    }
    Write-Progress -Activity "Reading task logs" -Completed
}

$rows = @($rawRows | Where-Object { $_ } | ForEach-Object {
    $resolvedProject = if (-not $_.ProjectId) { "(none)" } elseif ($projectNames.ContainsKey($_.ProjectId)) { $projectNames[$_.ProjectId] } else { "$($_.ProjectId) (deleted?)" }
    $resolvedEnv     = if (-not $_.EnvironmentId) { "" } elseif ($environmentNames.ContainsKey($_.EnvironmentId)) { $environmentNames[$_.EnvironmentId] } else { $_.EnvironmentId }
    $_ | Add-Member -NotePropertyName ProjectName -NotePropertyValue $resolvedProject -PassThru |
         Add-Member -NotePropertyName EnvironmentName -NotePropertyValue $resolvedEnv -PassThru
})

if ($rows.Count -eq 0) {
    Write-Warning "Checked $($tasks.Count) task(s) but found no worker leases."
    return
}

# --- Output -----------------------------------------------------------------------------------
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$detailPath = Join-Path $OutputPath "WorkerUsage-Detail.csv"
$rows |
    Sort-Object { [datetime]$_.UsedAt } -Descending |
    Select-Object TaskId, TaskType, ProjectName, EnvironmentName, State, WorkerName, WorkerPool, LeaseCount,
        @{ n = 'QueueTime';     e = { Format-Date $_.QueueTime } },
        @{ n = 'StartTime';     e = { Format-Date $_.StartTime } },
        @{ n = 'CompletedTime'; e = { Format-Date $_.CompletedTime } },
        TaskDescription |
    Export-Csv -Path $detailPath -NoTypeInformation -Encoding UTF8

function New-Summary($Rows, [string[]] $Keys) {
    $Rows | Group-Object -Property $Keys | ForEach-Object {
        $group = $_.Group
        $o = [ordered]@{}
        foreach ($key in $Keys) { $o[$key] = $group[0].$key }

        $o.TaskCount = @($group.TaskId | Sort-Object -Unique).Count
        if ($Keys -notcontains 'ProjectName') {
            $o.ProjectCount = @($group.ProjectName | Sort-Object -Unique).Count
            $o.Projects     = Join-Distinct $group.ProjectName
        }
        if ($Keys -notcontains 'WorkerName') {
            $o.WorkerCount = @($group.WorkerName | Sort-Object -Unique).Count
            $o.Workers     = Join-Distinct $group.WorkerName
        }
        if ($Keys -notcontains 'WorkerPool') { $o.WorkerPools = Join-Distinct $group.WorkerPool }
        $o.Environments = Join-Distinct $group.EnvironmentName

        $dates = @($group.UsedAt | Where-Object { $_ } | ForEach-Object { [datetime]$_ } | Sort-Object)
        $o.FirstUsed = if ($dates.Count) { Format-Date $dates[0] }  else { $null }
        $o.LastUsed  = if ($dates.Count) { Format-Date $dates[-1] } else { $null }

        [pscustomobject]$o
    } | Sort-Object TaskCount -Descending
}

$groupKeys = @{
    Project          = @('ProjectName')
    Worker           = @('WorkerName')
    WorkerPool       = @('WorkerPool')
    ProjectAndWorker = @('ProjectName', 'WorkerName')
    ProjectAndPool   = @('ProjectName', 'WorkerPool')
}

$stopwatch.Stop()
$taskCountWithWorkers = @($rows.TaskId | Sort-Object -Unique).Count
Write-Host ("Checked {0} task(s), {1} leased at least one worker, in {2:n1}s. Detail: {3}" -f $tasks.Count, $taskCountWithWorkers, $stopwatch.Elapsed.TotalSeconds, $detailPath)

if ($GroupBy -ne 'None') {
    $summary = New-Summary $rows $groupKeys[$GroupBy]
    $summaryPath = Join-Path $OutputPath "WorkerUsage-By$GroupBy.csv"
    $summary | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8
    Write-Host "Summary: $summaryPath"
    $summary
}
