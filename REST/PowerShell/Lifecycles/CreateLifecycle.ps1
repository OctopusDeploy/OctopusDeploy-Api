function Get-OctopusItems
{
	# Define parameters
    param(
    	$OctopusUri,
        $ApiKey,
        $SkipCount = 0
    )
    
    # Define working variables
    $items = @()
    $skipQueryString = ""
    $headers = @{"X-Octopus-ApiKey"="$ApiKey"}

    # Check to see if there there is already a querystring
    if ($octopusUri.Contains("?"))
    {
        $skipQueryString = "&skip="
    }
    else
    {
        $skipQueryString = "?skip="
    }

    $skipQueryString += $SkipCount
    
    # Get intial set
    $resultSet = Invoke-RestMethod -Uri "$($OctopusUri)$skipQueryString" -Method GET -Headers $headers

    # Check to see if it returned an item collection
    if ($resultSet.Items)
    {
        # Store call results
        $items += $resultSet.Items
    
        # Check to see if resultset is bigger than page amount
        if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage))
        {
            # Increment skip count
            $SkipCount += $resultSet.ItemsPerPage

            # Recurse
            $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
        }
    }
    else
    {
        return $resultSet
    }
    

    # Return results
    return $items
}

$apikey = 'API-YourAPIKey' # Get this from your profile
$OctopusUrl = 'https://YourURL' # Your Octopus Server address
$spaceName = "Default"

# Create headers for API calls
$headers = @{"X-Octopus-ApiKey"="$ApiKey"}

$lifecycleName = "MyLifecycle"

# Get space
$space = (Get-OctopusItems -OctopusUri "$octopusURL/api/spaces" -ApiKey $ApiKey) | Where-Object {$_.Name -eq $spaceName}

# Get lifecycles
$lifecycles = Get-OctopusItems -OctopusUri "$octopusURL/api/$($space.Id)/lifecycles" -ApiKey $apikey

# Check to see if lifecycle already exists
if ($null -eq ($lifecycles | Where-Object {$_.Name -eq $lifecycleName}))
{
    # Create payload
    $jsonPayload = @{
        Id = $null
        Name = $lifecycleName
        SpaceId = $space.Id
        Phases = @()
        ReleaseRetentionPolicy = @{
            ShouldKeepForever = $true
            QuantityToKeep = 0
            Unit = "Days"
        }
        TentacleRetentionPolicy = @{
            ShouldKeepForever = $true
            QuantityToKeep = 0
            Unit = "Days"
        }
        Links = $null
    }

    # Create new lifecycle
    Invoke-RestMethod -Method Post -Uri "$OctopusUrl/api/$($space.Id)/lifecycles" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $headers
}
else
{
    Write-Host "$lifecycleName already exists."
}