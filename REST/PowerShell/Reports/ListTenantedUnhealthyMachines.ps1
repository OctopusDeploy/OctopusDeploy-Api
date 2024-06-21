$ErrorActionPreference = "Stop";

# Add support for TLS 1.2 + TLS 1.3
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls13

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-XXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

$csvExportPath = "" # path:\to\variable.csv

# Validation that variable have been updated. Do not update the values here - they must stay as "https://your.octopus.app"
# and "API-XXXX", as this is how we check that the variables above were updated.
if ($octopusURL -eq "https://your.octopus.app" -or $octopusAPIKey -eq "API-XXXX") {
    Write-Host "You must replace the placeholder variables with values specific to your Octopus instance"
    exit 1
}

# Get space
Write-Output "Retrieving space '$($spaceName)'"
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# Cache all tenants
Write-Output "Retrieving all tenants"
$tenants = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/tenants" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $tenants += $response.Items
} while ($response.Links.'Page.Next')

# Cache all machines
Write-Output "Retrieving all machines"
$machines = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/machines" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $machines += $response.Items
} while ($response.Links.'Page.Next')

$results = @()

$unhealthyStatuses = @("Unavailable", "Unknown", "HasWarnings", "Unhealthy")

$unhealthyOrDisabledMachines = $machines | Where-Object { $_.IsDisabled -or $unhealthyStatuses -icontains $_.HealthStatus }
foreach ($machine in $unhealthyOrDisabledMachines) {
    if ($null -ne $machine.TenantIds -and $machine.TenantIds.Count -gt 0) {
        foreach ($tenantId in $machine.TenantIds) {
            # Add result per tenantId
            $result = [PsCustomObject]@{
                TenantName   = ($tenants | Where-Object { $_.Id -ieq $tenantId }).Name
                MachineName  = $machine.Name
                HealthStatus = $machine.HealthStatus
                IsDisabled   = $machine.IsDisabled
            }
        }
    }
    else {
        # Add result per machine
        $result = [PsCustomObject]@{
            TenantName   = ""
            MachineName  = $machine.Name
            HealthStatus = $machine.HealthStatus
            IsDisabled   = $machine.IsDisabled
        }
    }
    
    $results += $result
}

if ($results.Count -gt 0) {
    Write-Output ""
    Write-Output "Found $($results.Count) results:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Output "Exporting results to CSV file: $csvExportPath"
        $results | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
    else {
        $results | Sort-Object -Property TenantName | Format-Table -Property *
    }
}

$stopwatch.Stop()
Write-Output "Completed report execution in $($stopwatch.Elapsed)"