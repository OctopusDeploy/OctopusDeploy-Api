$ErrorActionPreference = 'Stop';

# Define working variables
$octopusURL = "https://your.octopus.server"
$octopusAPIKey = "API-KEY"

$csvExportPath = ''

function Invoke-PagedOctoGet($uriFragment)
{
    $items = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/$uriFragment" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ "X-Octopus-ApiKey" = $octopusAPIKey }
        $items += $response.Items
    } while ($response.Links.'Page.Next')

    $items
}

$users = Invoke-PagedOctoGet "api/users"
$usersWithEditPermissions = @()
foreach ($user in $users) {
    $permissions = (Invoke-RestMethod `
        -Uri "$octopusURL/api/users/$($user.Id)/permissions" `
        -Headers @{ "X-Octopus-ApiKey" = $octopusAPIKey }).SpacePermissions.PSObject.Members `
            | Where-Object MemberType -eq "NoteProperty"

    $editPermissionsForUser = @()
    foreach ($name in $permissions.Name) {
        if (($name -match "Edit") -or ($name -match "Create") -or ($name -match "Delete")) {
            $editPermissionsForUser += $name
        }
    }

    if ($editPermissionsForUser) {
        $usersWithEditPermissions += [PSCustomObject] @{
            Id = $user.Id
            EmailAddress = $user.EmailAddress
            Username = $user.Username
            DisplayName = $user.DisplayName
            IsActive = $user.IsActive
            IsService = $user.IsService
            Permissions = ($editPermissionsForUser -join ",")
        }
    }
}

if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
    Write-Host "Exporting results to CSV file: $csvExportPath"
    $usersWithEditPermissions | Export-Csv -Path $csvExportPath -NoTypeInformation
}

$usersWithEditPermissions | Format-Table