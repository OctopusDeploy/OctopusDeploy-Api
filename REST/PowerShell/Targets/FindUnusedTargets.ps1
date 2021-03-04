$ErrorActionPreference = "Stop";

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$octopusUrl = "https://local.octopusdemos.app" ## Octopus URL to look at
$octopusApiKey = "YOUR API KEY" ## API key of user who has permissions to view all spaces, cancel tasks, and resubmit runbooks runs and deployments
$daysSinceLastDeployment = 90 ## The number of days since the last deployment to be considered unused.  Any target without a deployment in the last [90] days is considered inactive.
$includeMachineLists = $false;  ## If true, all machines in each category will get listed out to the console.  If false, just a summary of information will be included.

$unsupportedCommunicationStyles = @("None")
$tentacleCommunicationStyles = @("TentaclePassive")

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item   
    )

    $octopusUrlToUse = $OctopusUrl
    if ($OctopusUrl.EndsWith("/"))
    {
        $octopusUrlToUse = $OctopusUrl.Substring(0, $OctopusUrl.Length - 1)
    }

    if ([string]::IsNullOrWhiteSpace($spaceId))
    {
        $url = "$octopusUrlToUse/api/$EndPoint"
    }
    else
    {
        $url = "$octopusUrlToUse/api/$spaceId/$EndPoint"    
    }  

    try
    {        
        if ($null -ne $item)
        {
            $body = $item | ConvertTo-Json -Depth 10
            Write-Verbose $body

            Write-Host "Invoking $method $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' 
        }

        Write-Verbose "No data to post or put, calling bog standard invoke-restmethod for $url"
        $result = Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'

        return $result               
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-Error "Unauthorized error returned from $url, please verify API key and try again"
            }
            elseif ($_.Exception.Response.statusCode -eq 403)
            {
                Write-Error "Forbidden error returned from $url, please verify API key and try again"
            }
            else
            {                
                Write-Error -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-Verbose $_.Exception
        }
    }

    Throw $_.Exception
}

function Update-CategorizedMachines
{
    param (
        $categorizedMachines,
        $space
    )

    $machineList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "machines?skip=0&take=10000" -spaceId $space.Id -method "GET"    

    foreach ($machine in $machineList.Items)
    {
        $categorizedMachines.TotalMachines += 1

        if ($unsupportedCommunicationStyles -contains $machine.Endpoint.CommunicationStyle)
        {
            $categorizedMachines.NotCountedMachines += $machine
            continue
        }

        if ($tentacleCommunicationStyles -contains $machine.Endpoint.CommunicationStyle)
        {
            $duplicateTentacle = $categorizedMachines.ListeningTentacles | Where-Object {$_.Thumbprint -eq $machine.Thumbprint -and $_.EndPoint.Uri -eq $machine.Endpoint.Uri }

            if ($null -ne $duplicateTentacle)
            {
                $categorizedMachines.DuplicateTentacles += $machine
                $categorizedMachines.ActiveMachines -= 1
            }

            $categorizedMachines.ListeningTentacles += $machine
        }        

        if ($machine.IsDisabled -eq $true)
        {
            $categorizedMachines.DisabledMachines += $machine
            continue
        }

        $categorizedMachines.ActiveMachines += 1

        if ($machine.Status -ne "Online")
        {
            $categorizedMachines.OfflineMachines += $machine            
        }

        $deploymentsList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "machines/$($machine.Id)/tasks?skip=0" -spaceId $space.Id -method "GET"

        if ($deploymentsList.Items.Count -le 0)
        {
            $categorizedMachines.UnusedMachines += $machine
            continue
        }

        $deploymentDate = [datetime]::Parse($deploymentsList.Items[0].CompletedTime)
        $deploymentDate = $deploymentDate.ToUniversalTime()

        $dateDiff = $currentUtcTime - $deploymentDate

        if ($dateDiff.TotalDays -gt $daysSinceLastDeployment)
        {
            $categorizedMachines.OldMachines += $machine                        
        }                 
    }
}

$currentUtcTime = $(Get-Date).ToUniversalTime()

$categorizedMachines = @{
    NotCountedMachines = @()
    DisabledMachines = @()
    ActiveMachines = 0
    OfflineMachines = @()
    UnusedMachines = @()
    OldMachines = @()
    TotalMachines = 0
    ListeningTentacles = @()
    DuplicateTentacles = @()
}

# Need to check the Octopus Server version for spaces feature
Write-Host "Checking Octopus Server version..."
$apiInfo = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint $null -method "GET"
$version = $apiInfo.Version
$versionParts = $apiInfo.Version.Split(".")

if ($versionParts[0] -ge 2019) {
    Write-Host "Octopus Server version $version supports spaces, checking all spaces."
    $spaceList = Invoke-OctopusApi -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "spaces?skip=0&take=1000" -spaceId $null -method "GET"
    foreach ($space in $spaceList.Items)
    {    
        Update-CategorizedMachines -categorizedMachines $categorizedMachines -space $space
    }
} else {
    Write-Host "Octopus Server version $version doesn't use spaces."
    Update-CategorizedMachines -categorizedMachines $categorizedMachines
}

Write-Host "This instance has a total of $($categorizedMachines.TotalMachines) targets across all spaces."
Write-Host "There are $($categorizedMachines.NotCountedMachines.Count) cloud regions which are not counted."
Write-Host "There are $($categorizedMachines.DisabledMachines.Count) disabled machines that are not counted."
Write-Host "There are $($categorizedMachines.DuplicateTentacles.Count) duplicate listening tentacles that are not counted (assuming you are using 2019.7.3+)."
Write-Host ""
Write-Host "This leaves you with $($categorizedMachines.ActiveMachines) active targets being counted against your license (this script is excluding the $($categorizedMachines.DuplicateTentacles.Count) duplicates in that active count)."
Write-Host "Of that combined number, $($categorizedMachines.OfflineMachines.Count) are showing up as offline."
Write-Host "Of that combined number, $($categorizedMachines.UnusedMachines.Count) have never had a deployment."
Write-Host "Of that combined number, $($categorizedMachines.OldMachines.Count) haven't done a deployment in over $daysSinceLastDeployment days."

if ($includeMachineLists -eq $true){
    Write-Host "Offline Targets"
    Foreach ($target in $categorizedMachines.OfflineMachines)
    {
        Write-Host " -  $($target.Name)"
    }

    Write-Host "No Deployment Ever Targets"
    Foreach ($target in $categorizedMachines.UnusedMachines)
    {
        Write-Host " -  $($target.Name)"
    }

    Write-Host " No deployments in the last $daysSinceLastDeployment days"
    Foreach ($target in $categorizedMachines.OldMachines)
    {
        Write-Host " -  $($target.Name)"
    }
}