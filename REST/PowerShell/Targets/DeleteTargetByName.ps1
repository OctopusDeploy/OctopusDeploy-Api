$octopusURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$machineName = "MachineName"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get machine list
    $targetList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines?name=$machineName&skip=0&take=1000" -Headers $header) 
    
    # Loop through list
    foreach ($target in $targetList.Items)
    {
        if ($target.Name -eq $machineName)
        {
            $targetId = $target.Id
            Write-Highlight "Deleting the target $targetId because the name matches the machineName"

            $deleteResponse = (Invoke-RestMethod "$OctopusUrl/api/$($space.Id)/machines/$targetId" -Headers $header -Method Delete)

            Write-Host "Delete Response $deleteResponse"
            break
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}