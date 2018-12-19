# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'
 
$octopusProjectName = @('') # Name of the project(s) you want to add/remove the variable set
$octopusVariableSetName = '' # !! CASE SENSATIVE !! Which variable set do you want to add/remove?
$apikey = 'API-Key' # Get this from your profile
$octopusURI = 'https://localhost' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

# Gets all existing variable sets from Octopus
$allVariableSets = $repository.LibraryVariableSets.FindAll()

# Gets the index of the variable set that we want to add
$indexOfVariableSetIAmUsing = $allVariableSets.name.IndexOf($octopusVariableSetName)

# Gets the object for the one variable set that we want
$libraryVariableSet = New-Object Octopus.Client.Model.LibraryVariableSetResource
$libraryVariableSet = $repository.LibraryVariableSets.Get($allVariableSets[$indexOfVariableSetIAmUsing].Id)

# You can use this to add 1 new variable to the library set
#$newVariable = new-object Octopus.Client.Model.VariableResource
#$newVariable.Name = "newVariableName"
#$newVariable.Value = "true"
 
#$variables = $repository.VariableSets.Get($libraryVariableSet.VariableSetId)
#$variables.Variables.Add($newVariable)
#$repository.VariableSets.Modify($variables)

# Find the project(s) you want
foreach ($name in $octopusProjectName) {
    $projects = $repository.Projects.FindByName($name)

    # Add/Remove Variable Set for all specified projects
    foreach ($project in $projects) {
        $project.IncludedLibraryVariableSetIds.Add($libraryVariableSet.Id) #change to .Remove for removing the variable set/script module from all projects
        $repository.Projects.Modify($project)
    }
}