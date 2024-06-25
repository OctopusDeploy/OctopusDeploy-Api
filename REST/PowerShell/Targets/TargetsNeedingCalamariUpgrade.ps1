$ErrorActionPreference = "Stop";

# Add support for TLS 1.2 + TLS 1.3
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls13

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

 #Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-XXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Validation that variable have been updated. Do not update the values here - they must stay as "https://your.octopus.app"
# and "API-XXXX", as this is how we check that the variables above were updated.
if ($octopusURL -eq "https://your.octopus.app" -or $octopusAPIKey -eq "API-XXXX") {
    Write-Host "You must replace the placeholder variables with values specific to your Octopus instance"
    exit 1
}

# Get space
Write-Verbose "Retrieving all spaces"
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?skip=0&take=100" -Headers $header 
$spaces = $spaces.Items 

$machines = @()

foreach ($space in $spaces) {
    Write-Verbose "Retrieving all machines in space '$($space.Name)'"

    
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/machines" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $machines += $response.Items
    } while ($response.Links.'Page.Next')
    Write-Verbose "Completed retrieval of all machines in space '$($space.Name)'"
}

$machinesNeedingCalamariUpgrade = $machines | Where-Object { $_.HasLatestCalamari -eq $false }

Write-Output "Found $($machinesNeedingCalamariUpgrade.Count) machines needing calamari upgrade"
if ($machinesNeedingCalamariUpgrade.Count -gt 0) {
    Write-Output ""
    $machinesNeedingCalamariUpgrade | Sort-Object -Property TenantName | Format-Table -Property SpaceId, Name, Id
}

$stopwatch.Stop()
Write-Output "Completed execution in $($stopwatch.Elapsed)"
