<#
.SYNOPSIS
Sets the Octopus Target Machine Upgrade Locked Value to True or False

.DESCRIPTION
Sets the Octopus Target Machine Upgrade Locked Value to True or False

.PARAMETER API URL
Specify the full Octopus API URL. E.g. "https://192.168.99.100/octopus/api".

.PARAMETER API Key
Specify the Octopus API Key. E.g. "API-XXXXXXXXXXXXXXXXX".

.PARAMETER Lock Upgrade
Specify whether to lock ($true) or unlock ($false) the version upgrade for all target machines.

.EXAMPLE
Set-OctopusTargetLockUpgrade -Url https://192.168.99.100/octopus/api/ -ApiKey API-XXXXXXXXXXXX -LockUpgrade $true

.EXAMPLE
Set-OctopusTargetLockUpgrade -Url https://10.254.1.10/octopus/api -ApiKey API-XXXXXXXXXXXX -LockUpgrade $false

#>

function Set-OctopusTargetLockUpgrade {
    param(
        [Parameter(Mandatory=$true)]
        $Url,
        [Parameter(Mandatory=$true)]
        $ApiKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet($false,$true)]
        $LockUpgrade
    )
    
    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw "Octopus API URL was not specified. Make sure you provid a valid URL to the Octopus API endpoint."
    }

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "Octopus API Key was not specified. Make sure you provide a valid API Key."
    }

    $LockUpgrade = [System.Convert]::ToBoolean($LockUpgrade)

    if ($Url.Substring($Url.Length - 1, 1) -eq "/") {
        $Url = $Url.Substring(0, $Url.Length - 1)
    }

    $header = @{ "X-Octopus-ApiKey" = $ApiKey }
    $allTargets = (Invoke-WebRequest $Url/machines/all -Headers $header).Content | ConvertFrom-Json

    foreach ($target in $allTargets) {
        $target.Endpoint.TentacleVersionDetails.UpgradeLocked = $LockUpgrade
        $body = $target | ConvertTo-Json -Depth 4
        $machineUrl = $machine.Links.Self
        $result = Invoke-WebRequest ($Url + $machineUrl.Substring($machineUrl.IndexOf("/machines/"), $machineUrl.Length - $machineUrl.IndexOf("/machines"))) -Method Put -Body $body -Headers $header
        if ($result.StatusCode -eq 200) {
            Write-Verbose "Modified $($target.Name) with UpgradeLocked value of $LockUpgrade"
        }
        else {
            Write-Error "Modification failed for $($target.Name)"
        }
    }
}