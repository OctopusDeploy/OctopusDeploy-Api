# This will test your active directory integration within Octopus Deploy itself.  
$octopusURL = "https://yourinstance.com"
$octopusAPIKey = "YOUR API KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$userNameToLookUp = "NAME TO SEARCH FOR" # Bob
$expectedMatch = "EXACT MATCH TO FIND" # Bob.Walker@mydomain.local

$directoryServicesResults = Invoke-RestMethod -Method GET -Uri "$octopusURL/api/externalusers/directoryServices?partialName=$([System.Web.HTTPUtility]::UrlEncode($userNameToLookUp))" -Headers $header

$foundUser = $false
foreach ($identity in $directoryServicesResults.Identities)
{
    if ($identity.IdentityProviderName -eq "Active Directory")
    {
        $claimList = $identity.Claims | Get-Member | where {$_.MemberType -eq "NoteProperty"} | Select-Object -Property "Name"

        foreach ($claimName in $claimList)
        {                  
            $claimName = $claimName.Name
            $claim = $identity.Claims.$ClaimName
            
            if ($claim.Value.ToLower() -eq $expectedMatch.Tolower() -and $claim.IsIdentifyingClaim -eq $true)
            {
                $foundUser = $true
                break
            }
        }

        if ($foundUser)
        {
            break
        }
    }
}

if ($foundUser)
{
    Write-Host "Successfully found the user $userNameToLookUp by matching $expectedMatch"
}
else 
{
    Write-Host "Unable to find user $UserNameToLookup with the claim $expectedMatch"
}