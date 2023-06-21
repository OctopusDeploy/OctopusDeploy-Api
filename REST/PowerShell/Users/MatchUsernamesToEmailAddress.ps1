# =============================================================
#      Change usernames to match email addresses (for AAD)     
# =============================================================

$ErrorActionPreference = "Stop";

# Define working variables
$OctopusURL = "http://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$Header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Get Users
$Users = (Invoke-RestMethod -Method GET "$OctopusURL/api/users/all" -Headers $Header)

$OriginalUsersJSON = (Invoke-RestMethod -Method GET "$OctopusURL/api/users/all" -Headers $Header)
$NoEmailUsers = @()
$ModifiedUserIds = @()

# Iterate through each user
Foreach ($User in $Users) {
    If (($User.IsService -eq $false) -and ($User.Username -ne $User.EmailAddress)) {
        If (!$User.EmailAddress) {
            $NoEmailUsers += $User.Id
        }
        $UserModifiedJSON = $User
        If ($User.EmailAddress) {
            $UserModifiedJSON.Username = $User.EmailAddress
            Invoke-RestMethod -Method PUT "$OctopusURL/api/users/$($UserModifiedJSON.Id)" -Body ($UserModifiedJSON | ConvertTo-Json -Depth 10) -Headers $Header
            $ModifiedUserIds += $UserModifiedJSON.Id
        }
    }
}
Write-Host "The folling User IDs were modified:"
$ModifiedUserIds
Write-Host ""

If ($NoEmailUsers) {
    Write-Warning "The following User IDs have no email associated (this excludes Service Accounts):"
    $NoEmailUsers
}

# OPTIONAL: Use the line below (uncommented) in the same PowerShell session you ran the script above to restore the users to their original JSON values.
# Foreach ($OriginalUser in $OriginalUsersJSON) { Invoke-RestMethod -Method PUT "$OctopusURL/api/users/$($OriginalUser.Id)" -Body ($OriginalUser | ConvertTo-Json -Depth 10) -Headers $Header }
