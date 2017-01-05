#This script was tested on Octopus 2.6.5 and 3.7.11 (Should work on all versions between those 2 and beyond)

##CONFIG##
$OctopusAPIkey = ""#Your Octopus API Key
$OctopusURL = ""# Your Octopus instance URL


##PROCESS##

#Getting all lifecycles
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$AllLifecycles = (Invoke-WebRequest $OctopusURL/api/lifecycles/all -Headers $header).content | ConvertFrom-Json 

#Setting retention policies that will be applied to each phase
$releaseRetentionPolicy = [PSCustomObject]@{
                Unit = "Items"
                QuantityToKeep = 25
                ShouldKeepForever = $false
            }

$tentacleRetentionPolicy = [PSCustomObject]@{
                Unit = "Items"
                QuantityToKeep = 0
                ShouldKeepForever = $true
            }

#Looping through each phase of each lifecycle, modifying the retention policies to match the ones above and then saving changes on the DB
foreach ($lifecycle in $AllLifecycles){
    Write-host "Working on lifecycle: [$($lifecycle.Name)]" -ForegroundColor Green

    foreach ($phase in $lifecycle.Phases){
        Write-Host "-- Modifying rentention policy of phase: [$($phase.Name)]" -ForegroundColor Magenta
        $phase.ReleaseRetentionPolicy = $releaseRetentionPolicy
        $phase.TentacleRetentionPolicy = $tentacleRetentionPolicy
    }

    $body = $lifecycle | ConvertTo-Json -Depth 6

    Write-Host "Saving changes in DB for lifecycle: [$($lifecycle.Name)]"

    Invoke-WebRequest $OctopusURL/api/lifecycles/$($lifecycle.id) -Method Put -Headers $header -Body $body
}