# Loops through all projects on an octopus server and exports any inline scripts to disk.
# Useful to move from inline scripts to scripts in packages (to gain advantages of source control)
# Currently assumes that the scripts are powershell

# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$apiKey = "API-1234567890ABCDEFG"
$octopusURI = "https://octopus.example.com"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$client = [Octopus.Client.OctopusAsyncClient]::Create($endpoint).Result
$repository = New-Object Octopus.Client.OctopusAsyncRepository $client

$allProjects = $Repository.Projects.FindAll().Result

foreach ($project in $allProjects) {
    $deploymentProcess = $Repository.DeploymentProcesses.Get($project.DeploymentProcessId).Result
    foreach ($step in $deploymentProcess.Steps){
        foreach ($action in $step.Actions){
            if ($action.ActionType -eq "Octopus.Script") {
                if ($action.Properties['Octopus.Action.Script.ScriptSource'].value -eq "Inline"){
                    # exclude step templates
                    if ($null -eq $action.Properties['Octopus.Action.Template.Id']) {

                        $directoryName = $project.Name -replace ' ', ''
                        if (-not (Test-Path $directoryName)) {
                            New-Item -Type Directory $directoryName
                        }
                        $fileName = "$($action.Name -replace ' ', '').ps1"

                        $fileContent = ($action.Properties['Octopus.Action.Script.ScriptBody'].value -split '\n') | foreach-object { $_.TrimEnd() }
                        write-host "Dumping inline script for $($project.Name) :: $($step.Name) :: $($action.Name) to $directoryName/$fileName"
                        Set-Content -Path "$directoryName/$fileName" -Value $fileContent.TrimEnd()
                    }
                }
            }
        }
    }
}
