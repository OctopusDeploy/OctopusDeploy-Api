# This will test your active directory integration within Octopus Deploy itself.  
$octopusURL = "https://yourinstance.com"
$octopusAPIKey = "YOUR API KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$teamNameToLookUp = "NAME TO SEARCH FOR" # Dev
$expectedMatch = "EXACT MATCH TO FIND" # Developers

$directoryServicesResults = Invoke-RestMethod -Method GET -Uri "$octopusURL/api/externalgroups/directoryServices?partialName=$([System.Web.HTTPUtility]::UrlEncode($teamNameToLookUp))" -Headers $header

$teamId = $null
foreach ($teamFound in $directoryServicesResults)
{    
    If ($teamFound.DisplayName -eq $expectedMatch)
    {        
        $teamId = $teamFound.Id
        break
    }    
}

if ($null -ne $teamId)
{
    Write-Host "Successfully found the team $teamNameToLookUp matching $expectedMatch. The id is $teamId"
}
else 
{
    Write-Host "Unable to find team $teamNameToLookUp matching $expectedMatch"
}