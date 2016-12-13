##Disclaimer: This script only lists the Purpuse, created date & ID of all the currently valid/registered API Keys of each user. It does not show the actual API Key value which cannot be recovered in any way after it was created.

##CONFIG##
$OctopusAPIkey = ""#Your Octopus API Key
$OctopusURL = ""#Your Octopus server root URL

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$list = @()

$AllUsers = (Invoke-WebRequest $OctopusURL/api/users/all -Headers $header).content | ConvertFrom-Json

foreach($user in $AllUsers){
    $apikeys = $null
    
    $apikeys = (Invoke-WebRequest ($OctopusURL + $user.links.apikeys.Split('{')[0]) -Headers $header).content | ConvertFrom-Json    

    $obj = [PSCustomObject]@{
                    UserName = $user.Username
                    ID = $user.Id
                    APIKeys = $apikeys.Items
                }
    $list += $obj
}

$list