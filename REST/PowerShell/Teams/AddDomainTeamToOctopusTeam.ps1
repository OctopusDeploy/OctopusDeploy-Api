$ErrorActionPreference = "Stop"

$octopusURL = "https://yoururl.com" # Replace with your instance URL
$octopusAPIKey = "YOUR API KEY" # Replace with a service account API Key
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$maxRecordsToUpdate = 2 # The max number of records you want to update in this batch

$newDomainToLookup = "Work" # Change this to the new domain

$skipIndex = 0
$recordsToBringBack = 30
$recordsUpdated = 0

while (1 -eq 1) #Continue until we reach the end of the user list or until we go over the max records to update
{
    Write-Host "Pulling teams starting at index $skipIndex and getting a max of $recordsToBringBack records back"
    $teamList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/teams?skip=$skipIndex&take=$recordsToBringBack" -Headers $header
    #Update to pull back the next batch of users
    $skipIndex = $skipIndex + $recordsToBringBack

    if ($teamList.Items.Count -eq 0)
    {
        break
    }

    foreach ($team in $teamList.Items)
    {
        if ($team.ExternalSecurityGroups.Count -eq 0)
        {
            # Skip teams which don't have an external AD group
            continue 
        }

        Write-Host "Checking to see if $($team.Name) is tied to an external active directory team."
        $activeDirectoryRecordsToAdd = @()

        foreach ($externalSecurityGroup in $team.ExternalSecurityGroups)
        {
            $externalName = $externalSecurityGroup.DisplayName            
            if ($null -eq $externalName)
            {
                continue
            }

            $teamNameToFind = "$newDomainToLookup\$externalName"
            $directoryServicesResults = Invoke-RestMethod -Method GET -Uri "$octopusURL/api/externalgroups/directoryServices?partialName=$([System.Web.HTTPUtility]::UrlEncode($teamNameToFind))" -Headers $header

            foreach ($result in $directoryServicesResults)
            {
                if ($result.DisplayName -eq $externalName)
                {
                    Write-Host "Found a matching team name, checking if the SID is already assigned to the team"
                    $foundMatch = $false
                    foreach ($group in $team.ExternalSecurityGroups)
                    {                        
                        if ($group.Id -eq $result.Id)
                        {
                            $foundMatch = $true
                            break
                        }
                    }

                    if ($foundMatch -eq $false)
                    {
                        $activeDirectoryRecordsToAdd += $result
                    }
                    else
                    {
                        Write-Host "The active directory group already existed on the team"
                    }

                    break
                }
            }
        }
        
        if ($activeDirectoryRecordsToAdd.Length -gt 0)
        {
            foreach ($teamToAdd in $activeDirectoryRecordsToAdd)
            {
                $team.ExternalSecurityGroups += $teamToAdd
            }

            Write-Host "Updating the team $($Team.Name) in Octopus Deploy"
            Invoke-RestMethod -Method PUT -Uri "$OctopusUrl/api/teams/$($team.Id)" -Headers $header -Body $($team | ConvertTo-Json -Depth 10)
            $recordsUpdated += 1
        }
        
    }

    if ($recordsUpdated -ge $maxRecordsToUpdate)
    {
        Write-Host "Reached the maximum number of records to update, stopping"
        break
    }
}