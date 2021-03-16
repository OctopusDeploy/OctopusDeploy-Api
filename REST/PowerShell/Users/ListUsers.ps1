$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

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

foreach($userRecord in $usersList) {
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

    if($userRecord.Identities.Count -gt 0) {
        if($includeActiveDirectoryDetails -eq $True) 
        {
            $activeDirectoryIdentity = $userRecord.Identities | Where-Object {$_.IdentityProviderName -eq "Active Directory"} | Select-Object -ExpandProperty Claims
            
            if($null -ne $activeDirectoryIdentity) {
                $user.AD_Upn = $activeDirectoryIdentity.upn.Value
                $user.AD_Sam = $activeDirectoryIdentity.sam.Value
                $user.AD_Email = $activeDirectoryIdentity.email.Value
            }
        }
        if($includeAzureActiveDirectoryDetails -eq $True) 
        {
            $azureAdIdentity = $userRecord.Identities | Where-Object {$_.IdentityProviderName -eq "Azure AD"} | Select-Object -ExpandProperty Claims
            if($null -ne $azureAdIdentity) {
                $user.AAD_Dn = $azureAdIdentity.dn.Value
                $user.AAD_Email = $azureAdIdentity.email.Value
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
