$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$machineUri = "http.yourhost.com"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?skip=0&take=100" -Headers $header 

# Loop through each space
foreach ($space in $spaces.Items) {
    Write-Host "Checking space $($space.Name) ($($space.Id))"
    $machines = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/machines?skip=0&take=1000" -Headers $header 
    $matchingMachine = $machines.Items | Where-Object { $_.Uri -like "*$machineUri*" } | Select-Object -First 1
    if($null -ne $matchingMachine) {
        Write-Host "Found matching machine $($matchingMachine.Name) ($($matchingMachine.Id))" -ForegroundColor Yellow
    }
}
