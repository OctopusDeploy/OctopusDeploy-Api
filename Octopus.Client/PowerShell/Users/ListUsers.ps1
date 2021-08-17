$ErrorActionPreference = "Stop";

# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"

# Optional: include user role details?
$includeUserRoles = $true

# Optional: include non-active users in output
$includeNonActiveUsers = $False

# Optional: include AD details
$includeActiveDirectoryDetails = $False

# Optional: include AAD details
$includeAzureActiveDirectoryDetails = $True

# Optional: set a path to export to csv
$csvExportPath = "path:\to\users.csv"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get users
$users = $repository.Users.GetAll()
$usersList = @()

# Check to see if we're filtering out inactive
if ($includeNonActiveUsers -eq $true)
{
    # Filter out inactive users
    Write-Host "Filtering users who arent active from results"
    $users = $users | Where-Object {$_.IsActive -eq $True}
}


# Loop through users
foreach ($user in $users)
{
    # Populate user details
    $userDetails = [ordered]@{
        Id = $user.Id
        Username = $user.Username
        DisplayName = $user.DisplayName
        IsActive = $user.IsActive
        IsService = $user.IsService
        EmailAddress = $user.EmailAddress
    }


    # Check to see if we're including user roles
    if ($includeUserRoles -eq $true)
    {
        $userDetails.Add("ScopedUserRoles", "")
        # Get users teams
        $userTeamNames = $repository.UserTeams.Get($user)

        # Loop through the users teams
        foreach ($teamName in $userTeamNames)
        {
            # Get the team
            $team = $repository.Teams.Get($team.Id)
            
            foreach ($role in $repository.Teams.GetScopedUserRoles($team))
            {
                $userDetails["ScopedUserRoles"] += "$(($repository.UserRoles.Get($role.UserRoleId).Name)) ($(($repository.Spaces.Get($role.SpaceId)).Name))|"
            }
        }
    }

    if ($includeActiveDirectoryDetails -eq $true)
    {
        # Get the identity provider object
        $activeDirectoryIdentity = $user.Identities | Where-Object {$_.IdentityProviderName -eq "Active Directory"}
        if ($null -ne $activeDirectoryIdentity) 
        {
            $userDetails.Add("AD_Upn", (($activeDirectoryIdentity.Claims | ForEach-Object {"$($_.upn.Value)"}) -Join "|"))
            $userDetails.Add("AD_Sam", (($activeDirectoryIdentity.Claims | ForEach-Object {"$($_.sam.Value)"}) -Join "|"))
            $userDetails.Add("AD_Email", (($activeDirectoryIdentity.Claims | ForEach-Object {"$($_.email.Value)"}) -Join "|"))
        }
    }
    
    if ($includeAzureActiveDirectoryDetails -eq $true)
    {
        $azureAdIdentity = $user.Identities | Where-Object {$_.IdentityProviderName -eq "Azure AD"}
        if ($null -ne $azureAdIdentity)
        {
            $userDetails.Add("AAD_Dn", (($azureAdIdentity.Claims | ForEach-Object {"$($_.dn.Value)"}) -Join "|"))
            $userDetails.Add("AAD_Email", (($azureAdIdentity.Claims | ForEach-Object {"$($_.email.Value)"}) -Join "|"))
        }
    }

    
    $usersList += $userDetails    
}

# Write header
$header = $usersList.Keys | Select-Object -Unique
Set-Content -Path $csvExportPath -Value ($header -join ",")

foreach ($user in $usersList)
{
    Add-Content -Path $csvExportPath -Value ($user.Values -join ",")
}

$usersList | Format-Table