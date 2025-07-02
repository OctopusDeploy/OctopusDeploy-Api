# This script will delete Runbook snapshots older than X date, leaving the newest snapshot. You may also set the Runbook retention policy using the optional working variables on lines 16-18.

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "My Project" # Use "All" to check *all* Runbooks in *all* Projects in the Space specified above
$runbookName = "My Runbook" # Use "All" to check *all* Runbooks in the *single* Project specified above
$keepNewerThanXDaysAgo = "7" # Keep Runbook snapshots newer than X days ago
$outputOnlyNoDelete = $true # Set to $true for a "dry run". Set to $false to delete Runbooks snapshots

# Optional - Set Runbooks retention policies working variables
$printRunbookRetentionPolicyOnly = $true # Setting to $true only prints the Runbook retention policy settings, set to $false to implement the changes specified below
$targetRetentionUnitType = "RunbookRuns" # Use "RunbookRuns" or "Days"
$targetRetentionQuantityToKeep = 100 # Default is 100 (RunbookRuns)

# Get space
$spaces = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
if ($projectName -ieq "All") {
    $runbooks = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/runbooks?skip=0&take=10000" -Headers $header
    $runbookList = $runbooks.Items
}
else {
    $projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header
    $project = $projects.Items | Where-Object { $_.Name -eq $projectName }
    
    # Get runbook(s)
    if ($runbookName -ieq "All") {
        $runbooks = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?skip=0&take=10000" -Headers $header
        $runbookList = $runbooks.Items
    }
    else {
        $runbooks = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header
        $runbookList = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }
    }
}

# Confirm results greater than 0
if (!$runbookList) {
    Write-Host "No Runbooks found. Check the values for `$spaceName, `$projectName, and `$runbookName."
    break
}

# Find target date
$deleteSnapshotOlderThan = (Get-Date).AddDays(-$keepNewerThanXDaysAgo).tostring("yyyy-MM-dd")

# Get snapshots for runbook(s)
foreach ($runbook in $runbookList) {
    if ($runbook.RunRetentionPolicy.Unit -eq "Items") { $unit = "RunbookRuns" } else { $unit = "Days" }
    if (($targetRetentionUnitType -ieq $unit) -and ($targetRetentionQuantityToKeep -lt $($runbook.RunRetentionPolicy.QuantityToKeep))) {
        Write-Host "Retention Policy for $($runbook.Name) ($($runbook.Id)) ($($runbook.ProjectId)) set to: $($runbook.RunRetentionPolicy.QuantityToKeep) $unit"
    }

    # (if not all snapshots are deleted for a particular runbook, increase take=value below or run the script again)
    if (!$printRunbookRetentionPolicyOnly) {
        $snapshots = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/runbooks/$($runbook.Id)/runbookSnapshots?take=10000" -Headers $header
        $snapshotsRemaining = $snapshots.Items.Count
        Write-Host "Found $snapshotsRemaining snapshots in $($runbook.Name) ($($runbook.Id)) ($($runbook.ProjectId))"

      # Loop through list
        foreach ($snapshot in $snapshots.Items) {
            if ($snapshot.Id -eq $runbook.PublishedRunbookSnapshotId)
            {
                Write-Host "$($snapshot.Id) is the current published runbook snapshot. Preserving."
            }
            else
            {
                if (($snapshot.Assembled -le $deleteSnapshotOlderThan) -and ($snapshotsRemaining -gt 1)) {
            
                    # Delete snapshots
                    Write-Host "Deleting $($snapshot.Id) in $($runbook.Name) ($($runbook.Id)) within $($runbook.ProjectId) created $($snapshot.Assembled)..."

                    if ($outputOnlyNoDelete -eq $false) {
                        Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbookSnapshots/$($snapshot.Id)" -Headers $header
                        $snapshotsRemaining--
                    }
                }
                if (($snapshot.Assembled -le $deleteSnapshotOlderThan) -and ($snapshotsRemaining -eq 1)) {
                    Write-Host "< Preserving final remaining snapshot > $($snapshot.Id) in $($runbook.Name) ($($runbook.Id)) within $($runbook.ProjectId) created $($snapshot.Assembled)..."
                }
            }
        }
    }
}
