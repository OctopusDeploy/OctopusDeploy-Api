# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
#Add-Type -Path 'Octopus.Client.dll' 

#S prefix on variables stands for "Source"
$SApiKey = $env:OctopusAPIKey#'' # Get this from your profile
$SOctopusURI = $env:OctopusURL#'' # Your Octopus Server address

$SEndpoint = New-Object Octopus.Client.OctopusServerEndpoint $SOctopusURI,$SApiKey 
$SRepository = New-Object Octopus.Client.OctopusRepository $SEndpoint

$SScriptModule = ""#name of the script module you want to migrate

$oldSM = $SRepository.LibraryVariableSets.FindOne({param($lvs) if (($lvs.ContentType -eq "scriptModule") -and ($lvs.Name -eq $SScriptModule)){$true}})
$oldLVS = $SRepository.VariableSets.Get($oldSM.VariableSetId)

#D prefix on variables stands for "Destination"
$DApiKey = "API-FBPZPITNVPIRQ0J8GQBXSJ14"#'' # Get this from your profile
$DOctopusURI = "http://dalmiropc:81"#'' # Your Octopus Server address

$DEndpoint = New-Object Octopus.Client.OctopusServerEndpoint $DOctopusURI,$DApiKey 
$DRepository = New-Object Octopus.Client.OctopusRepository $DEndpoint

$newSM = New-Object Octopus.Client.Model.LibraryVariableSetResource
$newSM.Name = $SScriptModule
$newSM.ContentType = "scriptModule"

$newSM = $DRepository.LibraryVariableSets.Create($newSM)
$newLVS = $DRepository.VariableSets.Get($newSM.VariableSetId)
$newLVS.Variables = $oldLVS.Variables

$DRepository.VariableSets.Modify($newLVS)

