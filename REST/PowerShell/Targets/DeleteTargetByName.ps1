$OctopusURL = ## YOUR URL, Example: https://something.octopus.com
$APIKey = ## API KEY
$machineName = ## Machine to delete

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Get a list of all machines"
$targetList = (Invoke-RestMethod "$OctopusUrl/api/machines?name=$machineName&skip=0&take=1000" -Headers $header)

## The above API call does a "starts with" search, this will ensure it only deletes the single machine
foreach($target in $targetList.Items)
{
    if ($target.Name -eq $machineName)
    {
        $targetId = $target.Id
        Write-Highlight "Deleting the target $targetId because the name matches the machineName"

        $deleteResponse = (Invoke-RestMethod "$OctopusUrl/api/machines/$targetId" -Headers $header -Method Delete)

        Write-Host "Delete Response $deleteResponse"
        break
    }
}