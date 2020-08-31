[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$baseUrl = "YOUR URL"
$apiKey = "YOUR API KEY"
$spaceId = "YOUR SPACE ID"
$projectNameToDuplicate = "To Do - Linux"
$sourceEnvironmentName = "Test"
$destinationEnvironmentName = "Production"

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $apiKey)

$tenantList = Invoke-RestMethod "$baseUrl/api/$SpaceId/tenants?skip=0&take=1000000" -Headers $header
$projectList = Invoke-RestMethod "$baseUrl/api/$SpaceId/projects?skip=0&take=1000000" -Headers $header
$environmentList = Invoke-RestMethod "$baseUrl/api/$SpaceId/environments?skip=0&take=1000000" -Headers $header

$projectInfo = @($projectList.Items | where {$_.Name -eq $projectNameToDuplicate })

if ($projectInfo.Length -le 0)
{
    Write-Host "Project Name $projectNameToDuplicate not found, exiting"
    exit 1
}
else
{
    Write-Host "Project found"
}

$sourceEnvironment = @($environmentList.Items | where {$_.Name -eq $sourceEnvironmentName })
$destinationEnvironment = @($environmentList.Items | where {$_.Name -eq $destinationEnvironmentName })

if ($sourceEnvironment.Length -le 0 -or $destinationEnvironment.Length -le 0)
{
    Write-Host "Unable to find the environment information, please check name and try again, exiting"
    Exit 1
}
else
{
    Write-Host "Environments found"
}

$projectId = $projectInfo[0].Id
$sourceEnvironmentId = $sourceEnvironment[0].Id
$destinationEnvironmentId = $destinationEnvironment[0].Id

foreach ($tenant in $tenantList.Items)
{
    $tenantId = $tenant.Id
    $tenantProjectLink = $tenant.ProjectEnvironments.$projectId    
    
    if ($tenantProjectLink -eq $null)
    {
        Write-Host "$($tenant.Name) is not assigned to $projectNameToDuplicate skipping"  
        continue     
    }

    if ($tenantProjectLink.Contains($sourceEnvironmentId) -eq $false -or $tenantProjectLink.Contains($destinationEnvironmentId) -eq $false)
    {
        Write-Host "$($tenant.Name) is not linked to both the source and destination environment, skipping"  
        continue  
    }

    $tenantVariables = Invoke-RestMethod "$baseUrl/api/$SpaceId/tenants/$tenantId/variables" -Headers $header

    Write-Host "Overwriting $destinationEnvironmentName variables with $sourceEnvironmentName for $($tenant.Name)"
    $tenantVariables.ProjectVariables.$projectId.Variables.$destinationEnvironmentId = $tenantVariables.ProjectVariables.$projectId.Variables.$sourceEnvironmentId
    
    $bodyAsJson = $tenantVariables | ConvertTo-Json -Depth 10
    $tenantVariables = Invoke-RestMethod "$baseUrl/api/$SpaceId/tenants/$tenantId/variables" -Method Post -Headers $header -Body $bodyAsJson
}
