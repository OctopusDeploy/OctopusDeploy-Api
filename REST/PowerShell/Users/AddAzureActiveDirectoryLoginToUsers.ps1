<#
.Synopsis
   Adds Azure Active Directory login identities to existing Octopus users
.DESCRIPTION
   Migrating to using Azure Active Directory to login to Octopus brings advantages. However, if you are already using AD domain login, and you are synchronizing email addresses to AAD using ADFS - new users will be created in Octopus where a match can't be found.
   It's helpful to be able to add those Azure AD login identities to Octopus in one hit to avoid new users (with limited permissions) from being created.
   This script does this by either:
    - looping over a provided CSV file or
    - a supplied username and email address
   It checks for an existing AAD login, and it will either replace it (if Force = $true) or create a new identity.
   You can optionally update the Display name and email address for the matching octopus user.

.EXAMPLE
    OctopusUsername, AzureEmailAddress, AzureDisplayName
    OctoUser, octouser@exampledomain.com, Octo User
.EXAMPLE
   AddAzureADLogins -OctopusURL "https://your.octopus.app/" -OctopusAPIKey "API-KEY" -OctopusUsername "OctoUser" -AzureEmailAddress "octouser@exampledomain.com" -AzureDisplayName "Octo User" -ContinueOnError $False -Force $False -WhatIf $False -DebugLogging $False
.EXAMPLE
   AddAzureADLogins -OctopusURL "https://your.octopus.app/" -OctopusAPIKey "API-KEY" -Path "/path/to/user_azure_ad_logins.csv" -ContinueOnError $False -Force $False -WhatIf $False -DebugLogging $False
#>
function AddAzureADLogins(
    [Parameter(Mandatory=$True)]
    [String]$OctopusURL,
    [Parameter(Mandatory=$True)]
    [String]$OctopusAPIKey,
    [String]$Path,
    [String]$OctopusUsername,
    [String]$AzureEmailAddress,
    [String]$AzureDisplayName = $null,
    [Boolean]$UpdateOctopusEmailAddress = $False,
    [Boolean]$UpdateOctopusDisplayName = $False,
    [Boolean]$ContinueOnError = $False,
    [Boolean]$Force = $False,
    [Boolean]$WhatIf = $True,
    [Boolean]$DebugLogging = $False
)
{
    Write-Host "OctopusURL: $OctopusURL"
    Write-Host "OctopusAPIKey: ********"
    Write-Host "Path: $Path"
    Write-Host "OctopusUsername: $OctopusUsername"
    Write-Host "AzureEmailAddress: $AzureEmailAddress"
    Write-Host "AzureDisplayName: $AzureDisplayName"
    Write-Host "UpdateOctopusEmailAddress: $UpdateOctopusEmailAddress"
    Write-Host "UpdateOctopusDisplayName: $UpdateOctopusDisplayName"
    Write-Host "ContinueOnError: $ContinueOnError"
    Write-Host "Force: $Force"
    Write-Host "WhatIf: $WhatIf"
    Write-Host "DebugLogging: $DebugLogging"
    Write-Host $("=" * 60)
    Write-Host

    if (-not [string]::IsNullOrWhiteSpace($OctopusURL)) {
        $OctopusURL = $OctopusURL.TrimEnd('/')
    }

    if($DebugLogging -eq $True) {
        $DebugPreference = "Continue"
    }

    $header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
    $usersToUpdate = @()
    $recordsUpdated = 0
    # Validate we have minimum required details.
    if ([string]::IsNullOrWhiteSpace($Path) -eq $true) {
        if([string]::IsNullOrWhiteSpace($OctopusUsername) -eq $true -or [string]::IsNullOrWhiteSpace($AzureEmailAddress) -eq $true) {
            Write-Warning "Path not supplied. OctopusUsername or AzureEmailAddress are either null, or an empty string."
            return
        }
        $usersToUpdate += [PSCustomObject]@{
            OctopusUsername = $OctopusUsername
            AzureEmailAddress = $AzureEmailAddress
            AzureDisplayName = $AzureDisplayName
        }
    }
    else {
        # Validate path 
        if(-not (Test-Path $Path)) {
            Write-Warning "Path '$Path' not found. Does a file exist at that location?"
            return
        }

        $usersToUpdate = Import-Csv -Path $Path -Delimiter ","
    }

    # Check if we have any users. If we do, get existing octopus users
    if($usersToUpdate.Count -gt 0) {
        Write-Host "Users to update: $($usersToUpdate.Count)"
        $ExistingOctopusUsers = @()
        $response = $null
        do {
            $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$OctopusURL/api/users" }
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
            $ExistingOctopusUsers += $response.Items
        } while ($response.Links.'Page.Next')

        Write-Debug "Found $($ExistingOctopusUsers.Count) existing Octopus users"
    }
    else {
        Write-Host "No users to update, exiting."
        return
    }
    
    if($ExistingOctopusUsers.Count -le 0) {
        Write-Warning "No users found in Octopus, exiting."
        return
    }

    foreach($user in $usersToUpdate)
    {
        Write-Host "Working on user $($User.OctopusUsername)"
        try {
            $existingOctopusUser = $ExistingOctopusUsers | Where-Object {$_.Username -eq $user.OctopusUsername} | Select-Object -First 1
            if($null -ne $ExistingOctopusUser) {
                Write-Debug "Found matching octopus user for $($user.OctopusUsername)"
                # Check if its a service account
                if($user.IsService -eq $True) {
                    Write-Debug "User $($user.OctopusUsername) is a Service account. This user won't be updated..."
                    continue
                }
                # Check if its an active account
                if($user.IsActive -eq $False) {
                    Write-Debug "User $($user.OctopusUsername) is an inactive account. This user won't be updated..."
                    continue
                }

                # Check for existing Azure AD Identity first.
                $azureAdIdentity = $existingOctopusUser.Identities | Where-Object {$_.IdentityProviderName -eq "Azure AD"} | Select-Object -First 1
                if($null -ne $azureAdIdentity) {
                    Write-Debug "Found existing AzureAD login for user $($user.OctopusUsername)"
                    if($Force -eq $True) {
                        Write-Debug "Force set to true. Replacing existing AzureAD Claims for Display Name and Email for user $($user.OctopusUsername)"
                        $azureAdIdentity.Claims.email.Value = $User.AzureEmailAddress
                        $azureAdIdentity.Claims.dn.Value = $User.AzureDisplayName
                    }
                    else {
                        Write-Debug "Force set to false. Skipping replacing existing AzureAD Claims for Display Name and Email for user $($user.OctopusUsername)"
                    }
                }
                else {
                    Write-Debug "No existing AzureAD login found for user $($user.OctopusUsername), creating new"
                    $newAzureADIdentity = @{
                        IdentityProviderName = "Azure AD"
                        Claims = @{
                            email = @{
                                Value = $User.AzureEmailAddress
                                IsIdentifyingClaim = $True
                            }
                            dn = @{
                                Value = $User.AzureDisplayName
                                IsIdentifyingClaim = $False
                            }
                        }
                    }
                    $existingOctopusUser.Identities += $newAzureADIdentity
                }

                # Update user's email address if set AND the value isnt empty.
                if($UpdateOctopusEmailAddress -eq $True -and -not([string]::IsNullOrWhiteSpace($User.AzureEmailAddress) -eq $true)) {
                    Write-Debug "Setting Octopus email address to: $($User.AzureEmailAddress)"
                    $existingOctopusUser.EmailAddress = $User.AzureEmailAddress
                }

                 # Update user's display name if set AND the value isnt empty.
                 if($UpdateOctopusDisplayName -eq $True -and -not([string]::IsNullOrWhiteSpace($User.AzureDisplayName) -eq $true)) {
                    Write-Debug "Setting Octopus display name to: $($User.AzureDisplayName)"
                    $existingOctopusUser.DisplayName = $User.AzureDisplayName
                }

                $userJsonPayload = $($existingOctopusUser | ConvertTo-Json -Depth 10)

                if($WhatIf -eq $True) {
                    Write-Host "What If set to true, skipping update for user $($User.OctopusUsername). For details of the payload, set DebugLogging to True"
                    Write-Debug "Would have done a POST to $OctopusUrl/api/users/$($existingOctopusUser.Id) with body:"
                    Write-Debug $userJsonPayload
                } 
                else {
                    Write-Host "Updating the user $($User.OctopusUsername) in Octopus Deploy"
                    Invoke-RestMethod -Method PUT -Uri "$OctopusUrl/api/users/$($existingOctopusUser.Id)" -Headers $header -Body $userJsonPayload | Out-Null
                    $recordsUpdated += 1
                }
            }
            else {
                Write-Warning "No match found for an existing octopus user with Username: $($User.OctopusUsername)"
            }
        }
        catch {
            If($ContinueOnError -eq $true) {
                Write-Warning "Error encountered updating $($User.OctopusUsername): $($_.Exception.Message), continuing..."
                continue
            }
            else {
                throw
            }
        }
    }
    Write-Host "Updated $($recordsUpdated) user records."
}

#AddAzureADLogins -OctopusURL "https://your.octopus.app/" -OctopusAPIKey "API-KEY" -Path "/path/to/user_azure_ad_logins.csv" -ContinueOnError $False -Force $False -WhatIf $False -DebugLogging $False