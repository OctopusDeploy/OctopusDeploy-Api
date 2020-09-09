# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# UserName of the user for which the API key will be created. You can check this value from the web portal under Configuration/Users
$UserName = "" 

# Purpose of the API Key. This field is mandatory.
$APIKeyPurpose = ""

try
{
    # Create payload
    $body = @{
        Purpose = $APIKeyPurpose
    } | ConvertTo-Json

    # Getting all users to filter target user by name
    $allUsers = (Invoke-WebRequest "$OctopusURL/api/users/all" -Headers $header -Method Get).content | ConvertFrom-Json

    # Getting user that owns API Key.
    $User = $allUsers | Where-Object { $_.username -eq $UserName }

    # Creating API Key
    $CreateAPIKeyResponse = (Invoke-WebRequest "$OctopusURL/api/users/$($User.id)/apikeys" -Method Post -Headers $header -Body $body -Verbose).content | ConvertFrom-Json

    # Printing new API Key
    Write-Output "API Key created: $($CreateAPIKeyResponse.apikey)"
}
catch
{
    Write-Host $_.Exception.Message
}