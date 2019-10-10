$OctopusUrl = "" # example https://myoctopus.something.com
$APIKey = ""
$environmentName = "Production"
$spaceName = "Default"

$header = @{ "X-Octopus-ApiKey" = $APIKey }

## First we need to find the space
$spaceList = Invoke-RestMethod "$OctopusUrl/api/spaces?Name=$spaceName" -Headers $header
$spaceFilter = @($spaceList.Items | Where {$_.Name -eq $spaceName})
$spaceId = $spaceFilter[0].Id
Write-Host "The spaceId for Space Name $spaceName is $spaceId"

## Next, let's find the environment
$environmentList = Invoke-RestMethod "$OctopusUrl/api/$spaceId/environments?skip=0&take=1000&name=$environmentName" -Headers $header
$environmentFilter = @($environmentList.Items | Where {$_.Name -eq $environmentName})
$environmentId = $environmentFilter[0].Id
Write-Host "The environmentId for Environment Name $environmentName in space $spaceName is $environmentId"

## Let's get a list of all the deployments which have gone to that environment
$deploymentList = Invoke-RestMethod "$octopusUrl/api/$spaceId/deployments?environments=$environmentId&skip=0&take=100000" -Headers $header
$packageList = @()
foreach ($deployment in $deploymentList.Items)
{
    $deploymentName = $deployment.Name
    $releaseId = $deployment.ReleaseId
    Write-Host "Getting the release details for $releaseId for $deploymentName"
    $restUrl = $OctopusUrl + $deployment.Links.Release
    $release = Invoke-RestMethod $restUrl -Headers $header

    if ($release.SelectedPackages.Count -gt 0)
    {
        Write-Host "The release has packages, getting the deployment process for $releaseId for $deploymentName"
        $restUrl = $OctopusUrl + $release.Links.ProjectDeploymentProcessSnapshot
        $deploymentProcess = Invoke-RestMethod $restUrl -Headers $header 

        foreach($package in $release.SelectedPackages)
        {
            $deploymentStep = $deploymentProcess.Steps | where {$_.Name -eq $package.StepName}
            $action = $deploymentStep.Actions | where {$_.Name -eq $package.ActionName}

            if ($action.ActionType -eq "Octopus.DeployRelease")
            {
                $actionName = $package.ActionName
                Write-Host "The 'package' for $actionName is really a deploy a release step, skipping this package"
            }
            else 
            {
                foreach ($stepPackage in $action.Packages)
                {
                    $packageToAdd = @{                        
                        PackageId = $stepPackage.PackageId
                        Version = $package.Version
                    }

                    $packageVersion = $packageToAdd.Version
                    $packageName = $packageToAdd.PackageId

                    $existingPackage = @($packageList | where {$_.PackageId -eq $packageToAdd.PackageId -and $_.Version -eq $packageToAdd.Version})

                    if ($existingPackage.Count -eq 0)
                    {
                        Write-Host "Adding package $packageName.$packageVersion to your list"
                        $packageList += $packageToAdd
                    }
                    else 
                    {                        
                        Write-Host "The package $packageName.$packageVersion has already been added to the list"
                    }
                }
            }
        }
    }                 
}

$packageCount = $packageList.Count
Write-Host "Found $packageCount package(s) in $environmentName"