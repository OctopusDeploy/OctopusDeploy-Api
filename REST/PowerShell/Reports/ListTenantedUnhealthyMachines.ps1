$ErrorActionPreference = "Stop";

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

$csvExportPath = "" # path:\to\variable.csv

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