$ErrorActionPreference = "Stop";

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


# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectGroupName = "MyProjectGroup"
$projectGroupDescription = "MyDescription"

# Get spaces
$spaces = Get-OctopusItems -OctopusUri "$octopusURL/api/spaces" -ApiKey $octopusAPIKey
$space = $spaces | Where-Object { $_.Name -eq $spaceName }

# Create project group payload
$projectGroupJson = @{
    Id = $null
    Name = $projectGroupName
    EnvironmentIds = @()
    Links = $null
    RetentionPolicyId = $null
    Description = $projectGroupDescription
}

# Create project group
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/projectgroups" -Body ($projectGroupJson | ConvertTo-Json -Depth 10) -Headers $header