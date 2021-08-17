$ErrorActionPreference = "Stop";

# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$csvExportPath = "path:\to\editpermissions.csv"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get users
$users = $repository.Users.GetAll()
$usersList = @()

# Loop through users
foreach ($user in $users)
{
    $userPermissions = $repository.UserPermissions.Get($user)
    $editPermissions = @()
    foreach ($spacePermission in $userPermissions.SpacePermissions)
    {
        foreach ($permissionName in $spacePermission.Keys)
        {
            if ($permissionName.ToString().ToLower().Contains("create") -or $permissionName.ToString().ToLower().Contains("delete") -or $permissionName.ToString().ToLower().Contains("edit"))
            {
                $editPermissions += $permissionName.ToString()
            }
        }
    }

    if ($null -ne $editPermissions -and $editPermissions.Count -gt 0)
    {
        $usersList += @{
            Id = $user.Id
            EmailAddress = $user.EmailAddress
            Username = $user.Username
            DisplayName = $user.DisplayName
            IsActive = $user.IsActive
            IsService = $user.IsService
            Permissions = ($editPermissions -join "| ")
        }
    }
}

if (![string]::IsNullOrWhiteSpace($csvExportPath))
{
    # Write header
    $header = $usersList.Keys | Select-Object -Unique
    Set-Content -Path $csvExportPath -Value ($header -join ",")

    foreach ($user in $usersList)
    {
        Add-Content -Path $csvExportPath -Value ($user.Values -join ",")
    }
}