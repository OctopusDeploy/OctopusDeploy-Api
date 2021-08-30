$octopusUrl = "https://local.octopusdemos.app"
$octopusApiKey = "YOUR API KEY"
$spaceId = "Spaces-1" 
$startDate = "2021-07-28"
$endDate = "2021-08-31"
$whatIf = $false

## This script assumes you are running 2020.6+ of Octopus Deploy.

$cachedResults = @{}

function Write-OctopusVerbose
{
    param($message)
    
    Write-Host $message  
}

function Write-OctopusInformation
{
    param($message)
    
    Write-Host $message  
}

function Write-OctopusSuccess
{
    param($message)

    Write-Host $message 
}

function Write-OctopusWarning
{
    param($message)

    Write-Warning "$message" 
}

function Write-OctopusCritical
{
    param ($message)

    Write-Error "$message" 
}

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item,
        $ignoreCache     
    )

    $octopusUrlToUse = $OctopusUrl
    if ($OctopusUrl.EndsWith("/"))
    {
        $octopusUrlToUse = $OctopusUrl.Substring(0, $OctopusUrl.Length - 1)
    }

    if ([string]::IsNullOrWhiteSpace($SpaceId))
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
            Write-OctopusVerbose $body

            Write-OctopusInformation "Invoking $method $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' 
        }

        if (($null -eq $ignoreCache -or $ignoreCache -eq $false) -and $method.ToUpper().Trim() -eq "GET")
        {
            Write-OctopusVerbose "Checking to see if $url is already in the cache"
            if ($cachedResults.ContainsKey($url) -eq $true)
            {
                Write-OctopusVerbose "$url is already in the cache, returning the result"
                return $cachedResults[$url]
            }
        }
        else
        {
            Write-OctopusVerbose "Ignoring cache."    
        }

        Write-OctopusVerbose "No data to post or put, calling bog standard invoke-restmethod for $url"
        $result = Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'

        if ($cachedResults.ContainsKey($url) -eq $true)
        {
            $cachedResults.Remove($url)
        }
        Write-OctopusVerbose "Adding $url to the cache"
        $cachedResults.add($url, $result)

        return $result

               
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-OctopusCritical "Unauthorized error returned from $url, please verify API key and try again"
            }
            elseif ($_.Exception.Response.statusCode -eq 403)
            {
                Write-OctopusCritical "Forbidden error returned from $url, please verify API key and try again"
            }
            else
            {                
                Write-OctopusVerbose -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode )"
            }            
        }
        else
        {
            Write-OctopusVerbose $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API please check the log for more details"
}

$recentDeletedTargets = Invoke-OctopusApi  -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "events?eventCategories=Deleted&from=$startDate&to=$endDate&documentTypes=Machines&spaces=all&includeSystem=false&excludeDifference=true&skip=0&take=1000" -method "GET" -item $null -spaceId $null

foreach ($auditEvent in $recentDeletedTargets.Items)
{
    $eventDetails = Invoke-OctopusApi  -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "events/$($auditEvent.Id)" -method "GET" -item $null -spaceId $null

    $oldMachineInformation = $eventDetails.ChangeDetails.DocumentContext

    if ($oldMachineInformation.EndPoint.DeploymentTargetType -ne "TentaclePassive")
    {
        Write-OctopusInformation "The target $($oldMachineInformation.Name) is not a listening tentacle, moving onto the next one"
        continue
    }

    $newTenantTag = @()

    foreach ($tenantTag in $oldMachineInformation.TenantTags)
    {
        $tenantTagSplit = $tenantTag -split "/"
        $tagSetId = $tenantTagSplit[0]        

        $tagSet = Invoke-OctopusApi  -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "tagsets/$tagSetId" -method "GET" -item $null -spaceId $oldMachineInformation.SpaceId:

        $matchingTag = $tagSet.Tags | Where-Object { $_.Id -eq $tenantTag }

        if ($null -ne $matchingTag)
        {
            $newTenantTag += $matchingTag.CanonicalTagName
        }
    }
    
    $newMachineRegistration = @{
        Id = $null        
        MachinePolicyId = $oldMachineInformation.MachinePolicyId
        Name = $oldMachineInformation.Name
        IsDisabled = $oldMachineInformation.IsDisabled
        HealthStatus = "Unknown"
        HasLatestCalamari = $true
        StatusSummary = $null
        IsInProcess = $true
        EndPoint = @{
            Id = $null
            CommunicationStyle = "TentaclePassive"
            Links = $null
            Uri = $oldMachineInformation.Endpoint.Uri
            Thumbprint = $oldMachineInformation.Endpoint.Thumbprint
            ProxyId = $oldMachineInformation.Endpoint.ProxyId
        }
        Links = $null
        Roles = $oldMachineInformation.Roles
        EnvironmentIds = $oldMachineInformation.EnvironmentIds
        TenantIds = $oldMachineInformation.TenantIds
        TenantTags = $newTenantTag
        TenantedDeploymentParticipation = $oldMachineInformation.TenantedDeploymentParticipation
    }
    
    $matchingTargetList = Invoke-OctopusApi  -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "machines?skip=0&take=100&partialName=$([uri]::EscapeDataString($oldMachineInformation.Name))" -method "GET" -item $null -spaceId $oldMachineInformation.SpaceId
    $matchingTarget = $matchingTargetList.Items | Where-Object {$_.Name.Tolower().Trim() -eq $oldMachineInformation.Name.ToLower().Trim() }

    if ($null -eq $matchingTarget)
    {
        Write-OctopusInformation "No existing matching targets found, restoring the machine $($oldMachineInformation.Name)"

        if ($whatIf -eq $false)
        {
            $newMachine = Invoke-OctopusApi  -octopusUrl $octopusUrl -apiKey $octopusApiKey -endPoint "machines" -method "POST" -item $newMachineRegistration -spaceId $oldMachineInformation.SpaceId

            Write-OctopusInformation "The new machine id for $($newMachine.Name) is $($newMachine.Id)"
        }
        else
        {
            Write-OctopusInformation "What if set to true, skipping."    
        }
    }
    else
    {
        Write-OctopusInformation "The machine $($oldMachineInformation.Name) already exists.  Skipping."    
    }
}