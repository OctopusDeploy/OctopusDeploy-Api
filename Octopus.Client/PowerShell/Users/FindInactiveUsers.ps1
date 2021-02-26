# Find any users that have not been active on Octopus in the last 90 days
$octopusURL = "https://your-octopus-instance/"
$octopusAPIKey = "API-xxxx"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$endDate = Get-Date -format "yyyy-MM-dd"
$startDate = (Get-Date).AddDays(-90).ToString("yyyy-MM-dd")

# Get users
$users = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/users" -Headers $header

Write-Host "Users not active in last 90 days:"

foreach ($user in $users.Items) {    
    # Get events
    $audit = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/events?users=$($user.Id)&from=$($startDate)T00%3A00%3A00%2B00%3A00&to=$($endDate)T23%3A59%3A59%2B00%3A00&spaces=all&includeSystem=false&excludeDifference=true" -Headers $header

    if ($audit.TotalResults -eq 0){
        Write-Host "    $($user.Username)"
    }
}
