$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Optional: include user role details?
$includeUserRoles = $False

# Optional: include non-active users in output
$includeNonActiveUsers = $False

# Optional: include AD details
$includeActiveDirectoryDetails = $False

# Optional: include AAD details
$includeAzureActiveDirectoryDetails = $False

# Optional: set a path to export to csv
$csvExportPath = ""

$users = @()
$usersList = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/users" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $usersList += $response.Items
} while ($response.Links.'Page.Next')

# Filter non-active users
if($includeNonActiveUsers -eq $False) {
    Write-Host "Filtering users who arent active from results"
    $usersList = $usersList | Where-Object {$_.IsActive -eq $True}
}

# If we are including user roles, need to get team details
if($includeUserRoles -eq $True) {
    $teams = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/teams" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $teams += $response.Items
    } while ($response.Links.'Page.Next')

    foreach($team in $teams) {
        $scopedUserRoles = Invoke-RestMethod -Method Get -Uri ("$octopusURL/api/teams/$($team.Id)/scopeduserroles") -Headers $header
        $team | Add-Member -MemberType NoteProperty -Name "ScopedUserRoles" -Value $scopedUserRoles.Items
    }

    $allUserRoles = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/userroles" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $allUserRoles += $response.Items
    } while ($response.Links.'Page.Next')

    $spaces = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/spaces" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $spaces += $response.Items
    } while ($response.Links.'Page.Next')
}

foreach($userRecord in $usersList) {
    $usersRoles = @()

    $user = [PSCustomObject]@{
        Id = $userRecord.Id
        Username = $userRecord.Username
        DisplayName = $userRecord.DisplayName
        IsActive = $userRecord.IsActive
        IsService = $userRecord.IsService
        EmailAddress = $userRecord.EmailAddress
    }
    if($includeActiveDirectoryDetails -eq $True) 
    {
        $user | Add-Member -MemberType NoteProperty -Name "AD_Upn" -Value $null
        $user | Add-Member -MemberType NoteProperty -Name "AD_Sam" -Value $null
        $user | Add-Member -MemberType NoteProperty -Name "AD_Email" -Value $null
    }
    if($includeAzureActiveDirectoryDetails -eq $True) 
    {
        $user | Add-Member -MemberType NoteProperty -Name "AAD_DN" -Value $null
        $user | Add-Member -MemberType NoteProperty -Name "AAD_Email" -Value $null
    }

    if($includeUserRoles -eq $True) {
        $usersTeams = $teams | Where-Object {$_.MemberUserIds -icontains $user.Id}
        foreach($userTeam in $usersTeams) {
            $roles = $userTeam.ScopedUserRoles
            foreach($role in $roles) {
                $userRole = $allUserRoles | Where-Object {$_.Id -eq $role.UserRoleId} | Select-Object -First 1
                $roleName = "$($userRole.Name)"
                $roleSpace = $spaces | Where-Object {$_.Id -eq $role.SpaceId} | Select-Object -First 1
                if (![string]::IsNullOrWhiteSpace($roleSpace)) {
                    $roleName += " ($($roleSpace.Name))"
                }
                $usersRoles+= $roleName
            }
        }
        $user | Add-Member -MemberType NoteProperty -Name "ScopedUserRoles" -Value ($usersRoles -Join "|")
    }

    if($userRecord.Identities.Count -gt 0) {
        if($includeActiveDirectoryDetails -eq $True) 
        {
            $activeDirectoryIdentity = $userRecord.Identities | Where-Object {$_.IdentityProviderName -eq "Active Directory"} | Select-Object -ExpandProperty Claims
            if($null -ne $activeDirectoryIdentity) {               
                $user.AD_Upn = (($activeDirectoryIdentity | ForEach-Object {"$($_.upn.Value)"}) -Join "|")
                $user.AD_Sam = (($activeDirectoryIdentity | ForEach-Object {"$($_.sam.Value)"}) -Join "|")
                $user.AD_Email = (($activeDirectoryIdentity | ForEach-Object {"$($_.email.Value)"}) -Join "|")
            }
        }
        if($includeAzureActiveDirectoryDetails -eq $True) 
        {
            $azureAdIdentity = $userRecord.Identities | Where-Object {$_.IdentityProviderName -eq "Azure AD"} | Select-Object -ExpandProperty Claims
            if($null -ne $azureAdIdentity) {
                $user.AAD_Dn = (($azureAdIdentity | ForEach-Object {"$($_.dn.Value)"}) -Join "|")
                $user.AAD_Email = (($azureAdIdentity | ForEach-Object {"$($_.email.Value)"}) -Join "|")
            }
        }
    }
    $users+=$user
}

if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
    Write-Host "Exporting results to CSV file: $csvExportPath"
    $users | Export-Csv -Path $csvExportPath -NoTypeInformation
}

$users | Format-Table
