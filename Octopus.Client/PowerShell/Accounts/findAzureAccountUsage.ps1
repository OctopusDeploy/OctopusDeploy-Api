#This script will look for the usage of a specific Azure Account in all projects and print the results

##CONFIG##

$apikey = 'API-xxxx' # Get this from your profile

$octopusURI = 'http://YourOctopusServer' # Your Octopus Server address

$AccountName = "Your Account Name" #Name of the account that you want to find

##PROCESS##

Add-Type -Path 'Octopus.Client.dll'

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$AllProjects = $Repository.Projects.FindAll()

$Account = $Repository.Accounts.FindByName($AccountName)

foreach($project in $AllProjects){
    $deploymentProcess = $Repository.DeploymentProcesses.Get($project.deploymentprocessid)

    foreach($step in $deploymentProcess.steps){
        foreach ($action in $step.actions){
            if($action.Properties['Octopus.Action.Azure.AccountId'].value -eq $Account.Id){
                Write-Output "Project - [$($project.name)]"
                Write-Output "`t- Account [$($account.name)] is being used in the step [$($step.name)]"
            }
        }
    }
}