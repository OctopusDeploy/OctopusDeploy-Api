$octopusApiKey = "YOUR API KEY"
$octopusUrl = "YOUR URL" 
$header = @{ "X-Octopus-ApiKey" = $octopusApiKey }

$spaceResults = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/spaces?skip=0&take=100000" -Headers $header
foreach ($space in $spaceResults.Items)
{
    Write-Host $space.Name
    $spaceId = $space.id
    $feedList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/Feeds" -Headers $header
    foreach ($feed in $feedList.Items)
    {
        if ($feed.FeedType -ne "BuiltIn")
        {
            continue
        }

        $packageList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/feeds/$($feed.Id)/packages/search" -Headers $header     
        foreach ($package in $packageList.Items)
        {
            Write-Host "    $($package.Name)"
            $packageVersionList = Invoke-RestMethod -Method Get -Uri "$OctopusUrl/api/$spaceId/feeds/$($feed.Id)/packages/versions?packageId=$($package.Id)&skip=0&take=100000" -Headers $header
            foreach ($packageVersion in $packageVersionList.Items)
            {
                $sizeInKB = $packageVersion.SizeBytes / 1024
                Write-Host "        $($packageVersion.Version) - $sizeInKB KB"
            }
        }
    }
}