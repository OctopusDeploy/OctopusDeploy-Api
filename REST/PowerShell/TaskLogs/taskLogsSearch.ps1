<#
This script automates the process of finding specific text within Octopus Deploy task logs.
It retrieves the most recent deployment tasks via the Octopus API, downloads the full 
raw log transcript for each, and scans for a user-defined keyword (e.g., specific error codes, 
file names, or warnings).

If a match is found, it outputs the Deployment Description and a direct URL link 
to the task in the Octopus UI.
#>

$octopusUrl = "https://your-octopus-url"
$apiKey = "API-x"
$spaceName = "Default" 
$searchKeyword = "search keywords" # The text to find
$taskLimit = 20 # Max number of recent tasks to scan

$header = @{ "X-Octopus-ApiKey" = $apiKey }

# Get the list of recent deployment tasks
Write-Host "Fetching last $taskLimit tasks..." -ForegroundColor Cyan

$space = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

$tasksEndpoint = "$octopusUrl/api/$spaceId/tasks?skip=0&take=$taskLimit&name=Deploy"
# Note: You can add "&environment=Environments-1" to the URL above to filter further

try {
    $Response = Invoke-RestMethod -Uri $tasksEndpoint -Headers $header -Method Get
    $tasks = $Response.Items
}
catch {
    Write-Error $_.Exception
    exit
}

if (-not $tasks) {
    Write-Host "No tasks found."
    exit
}

# Loop through tasks, download raw log, and search
Write-Host "Searching logs for keyword: '$searchKeyword'" -ForegroundColor Yellow
$matchesFound = 0

foreach ($task in $tasks) {
    $taskId = $task.Id
    $description = $task.Description
    
    # Visual progress indicator
    Write-Host -NoNewline "." 

    # Fetch the RAW log (returns plain text)
    $rawLogEndpoint = "$octopusUrl/api/$spaceId/tasks/$taskId/raw"
    
    try {
        # Using -ErrorAction SilentlyContinue because some system tasks might not have raw logs
        $logContent = Invoke-RestMethod -Uri $rawLogEndpoint -Headers $header -Method Get -ErrorAction SilentlyContinue
        
        if ($logContent -and ($logContent -match $searchKeyword)) {
            Write-Host "`n[MATCH FOUND] $description" -ForegroundColor Green
            
            # Construct the UI Link
            $taskWebLink = "$octopusUrl/app#/$spaceId/tasks/$taskId"
            Write-Host "Link: $taskWebLink" 
            Write-Host "---------------------------------------------------"
            $matchesFound++
        }
    }
    catch {
        Write-Host $rawLogEndpoint
        Write-Host $_.Exception
    }
}

Write-Host "`nSearch complete. Found $matchesFound matches." -ForegroundColor Cyan
