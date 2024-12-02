# This is a script that can enable or disable a user based on their username or email address in Octopus

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$userAccountEmailAddress = "OCTOPUS_EMAIL@SOMEEMAIL.COM"
$userAccountUsername = "OCTOPUS_USERNAME"
$usernameOrEmail = "email" # Set to "username" if you wish to delete by username
$enable = $false # Set to $true to enable an account, set to $false to disable an account

# Find user account
$allUserAccounts = Invoke-RestMethod -Method GET -uri "$octopusURL/api/users/all" -Headers $header

If ($usernameOrEmail -ieq "email") {   
    $userAccount = ($allUserAccounts | Where-Object { $_.EmailAddress -ieq $userAccountEmailAddress }) | Select-Object -First 1
}
Else {
    If ($usernameOrEmail -ieq "username") {
        $userAccount = ($allUserAccounts | Where-Object { $_.Username -ieq $userAccountUsername }) | Select-Object -First 1
    }
}

# Enable or disable user account
If (!$userAccount) {
    Write-Warning "No users accounts found using the input parameters."
    Break
}

If ($userAccount) {
    Write-host "Disabling the account $($userAccount.DisplayName) ($($userAccount.Id))"
    $userAccount.IsActive = $enable
    $disableUser = Invoke-RestMethod -Method PUT -uri "$octopusURL/api/users/$($userAccount.Id)" -Body ($userAccount | ConvertTo-Json -Depth 10) -Headers $header
    Write-Host "DONE!"
}
