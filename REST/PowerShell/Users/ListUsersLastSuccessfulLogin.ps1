################################################################################################
### Note: This script may indicate false positives for the last successful log-in for a user
### if the audit event date range is too small to capture the last successful log-in event.
################################################################################################

$ErrorActionPreference = "Stop";

# Fix ANSI Color on PS Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Only get the last 30 days of records. Change this value to get more records
$NumberOfDaysEvents = 30

# Optional: set a path to export to csv
$csvExportPath = ""

# Optional: include non-active users in output
$includeNonActiveUsers = $False

$now = Get-Date
$from = $now.AddDays(-$NumberOfDaysEvents).ToString("yyyy-MM-ddTHH:mm:ss")
$to = $now.ToString("yyyy-MM-ddTHH:mm:ss")

$eventsFrom = $([System.Web.HTTPUtility]::UrlEncode($from))
$eventsTo = $([System.Web.HTTPUtility]::UrlEncode($to))

$octopusURL = $octopusURL.TrimEnd('/')

Write-Output "Retrieving users"
$users = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/users" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $usersList += $response.Items
} while ($response.Links.'Page.Next')

# Filter non-active users
if($includeNonActiveUsers -eq $False) {
    Write-Output "Filtering users who arent active from results"
    $usersList = $usersList | Where-Object {$_.IsActive -eq $True}
}

$eventsUrl = "$octopusURL/api/events?eventCategories=LoginSucceeded&documentTypes=Users&from=$eventsFrom&to=$eventsTo&spaces=all&includeSystem=true&excludeDifference=true"

Write-Output "Retrieving successful log in events from '$($from)' to '$($to)'"
$events = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { $eventsUrl }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $events += $response.Items
} while ($response.Links.'Page.Next')

Write-Output "Processing $($usersList.Count) user records"
foreach($userRecord in $usersList) {
   
    $lastLoginEvent = $events | Where-Object { $_.RelatedDocumentIds -icontains $userRecord.Id } | Sort-Object -Property Occurred -Descending | Select-Object -First 1
    $user = [PSCustomObject]@{
        Id = $userRecord.Id
        Username = $userRecord.Username
        DisplayName = $userRecord.DisplayName
        IsActive = $userRecord.IsActive
        ServiceAccount = $userRecord.IsService
        EmailAddress = $userRecord.EmailAddress
        LastSuccessfulLogin = if($lastLoginEvent) { $lastLoginEvent.Occurred } else { $null }
    }
    $users+=$user
}

if ($users.Count -gt 0) {
    Write-Output ""
    Write-Output "Found $($users.Count) users:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Output "Exporting results to CSV file: $csvExportPath"
        $users | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
    else {
        $users | Format-Table
    }
}

$stopwatch.Stop()
Write-Output "Completed report execution in $($stopwatch.Elapsed)"