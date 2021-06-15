# Use this script to clone an Octopus UserRole with a new name
$octopusUrl = "https://your.octopus.server"
$apiKey = "API-KEY"
$userRoleNameToDuplicate = "Project lead"
$newRoleName = "Project lead (Safe)"

$headers = @{ "X-Octopus-ApiKey" = $apiKey }
$encodedName = [System.Web.HTTPUtility]::UrlEncode($userRoleNameToDuplicate)
$userRole = (Invoke-RestMethod `
                -Uri "$octopusUrl/api/userroles?partialName=$encodedName" `
                -Headers $headers -UseBasicParsing).Items `
                    | Where-Object -Property Name -eq $userRoleNameToDuplicate


if (!$userRole) {
    throw "Error: No UserRole found with name: $userRoleNameToDuplicate"
}

$newRole = $userRole
$newRole.Name = $newRoleName

Invoke-RestMethod -Uri "$octopusUrl/api/userroles" -Method Post -Headers $headers -Body ($newRole | ConvertTo-Json)
