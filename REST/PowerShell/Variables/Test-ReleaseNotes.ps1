
$ReleaseNotes = @"
* [311006](https://AzureDevOps/DefaultCollection/83aaace0-5e0f-4553-b3d1-5060e8012bb0/_workitems/edit/311006): My Reports History:: error creating report but status in grid is In Progress <span class='label'>Ready for Test</span>  
* [311833](https://AzureDevOps/DefaultCollection/83aaace0-5e0f-4553-b3d1-5060e8012bb0/_workitems/edit/311833): [Generic Installer App] "Browser not supported" issue on iPhone <span class='label'>Ready for Test</span>  
* [311835](https://AzureDevOps/DefaultCollection/83aaace0-5e0f-4553-b3d1-5060e8012bb0/_workitems/edit/311835): Returns 504 error when attempting to generate for entire base <span class='label'>Merged Into Next Release</span> <span class='label label-info'>performance</span> 
"@
$ReleaseNotes = $ReleaseNotes.Replace('"','\"')

$ReleaseNotes

octo create-release --apiKey "API-BTVNKGWA5YKPNASEMEFR8QYMGEQ" --server "https://octopus.markharrison.dev" --project "Azure CLI play" --version "1.0.1" --ignoreExisting --releaseNotes $($ReleaseNotes)