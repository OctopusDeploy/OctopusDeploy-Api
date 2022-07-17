$ErrorActionPreference = "Stop";

# Define working variables
$OctopusUrl = "https://youroctourl" # Octopus URL
$APIKey = "API-YOURAPIKEY" # API Key that can read the number of machines
$header = @{ "X-Octopus-ApiKey" = $APIKey }

# Get list of Spaces
$spaces = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header)

# Getting the deployment targets in each space
Foreach ($space in $spaces) {
    $spaceid = "$($space.id)"
    $spacename = "$($space.name)"
    If ($spacename -ne "Private")
        {
        write-host "$($spaceid) ($($spacename))"
        $machines = (Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$($spaceid)/machines?skip=0&take=100000" -Headers $header)
        $items = $machines.items
        Foreach ($item in $items) {
                 $machineid = $($item.id)
                $machinename = $($item.name)
                write-host "$($machineid)  `t($($machinename)) - $OctopusUrl/api/$($spaceid)/infrastructure/machines/$($machineid)"
        }
    }
    write-host "---"
}
