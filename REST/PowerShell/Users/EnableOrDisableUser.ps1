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
    $userAccount = $allUserAccounts | Where-Object { $_.EmailAddress -ieq $userAccountEmailAddress }
    if ($userAccount.count -gt 1) {
        Write-Warning "Multiple accounts detected with the specified email. Consider specifying an account by username instead."
        Foreach ($account in $userAccount) {
            Write-Host "Username: $($account.Username)"
            Write-Host "Email: $($account.EmailAddress)"
            Write-Host "Id: $($account.Id)"
            Write-Host "---"
        }
        Break
    }
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
    If ($enable) { $enableDisable = "enabled" }; If (!$enable) { $enableDisable = "disabled" }
    Write-Host "Committing changes to account: $($userAccount.DisplayName) ($($userAccount.Id))"
    $userAccount.IsActive = $enable
    $disableUser = Invoke-RestMethod -Method PUT -uri "$octopusURL/api/users/$($userAccount.Id)" -Body ($userAccount | ConvertTo-Json -Depth 10) -Headers $header
    Write-Host "User account $enableDisable"
}
