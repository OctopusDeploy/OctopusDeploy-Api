# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 
 
$octopusProjectName = @() # Name of the project(s) you want to add/remove the variable set
$octopusVariableSetName = "" # !! CASE SENSATIVE !! Which variable set do you want to add/remove?
$apikey = 'API-ABCDEFGHIJKLMNOPQ' # Get this from your profile
$octopusURI = 'https://yourplace.octopus.app' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

# Gets all existing variable sets from Octopus
$allVariableSets = $repository.LibraryVariableSets.FindAll()

# Gets the index of the variable set that we want to add
$indexOfVariableSetIAmUsing = $allVariableSets.name.IndexOf($octopusVariableSetName)

# Gets the object for the one variable set that we want
$libraryVariableSet = New-Object Octopus.Client.Model.LibraryVariableSetResource
$libraryVariableSet = $repository.LibraryVariableSets.Get($allVariableSets[$indexOfVariableSetIAmUsing].Id)

# I don't really know what this does
$ignoreConfigTransformVariable = new-object Octopus.Client.Model.VariableResource
$ignoreConfigTransformVariable.Name = "Octopus.Action.Package." + $libraryVariableSet.Name
$ignoreConfigTransformVariable.Value = "true"

$variables = $repository.VariableSets.Get($libraryVariableSet.VariableSetId)
$variables.Variables.Add($ignoreConfigTransformVariable)
$repository.VariableSets.Modify($variables)

$projects = @()
# Find the project(s) you want
foreach($name in $octopusProjectName){
    $allProjects = $repository.Projects.FindAll()
    $indexOfProjectIAmUsing = $allProjects.slug.IndexOf($name.ToLower())
    $project = $allProjects[$indexOfProjectIAmUsing]
    $projects += $project
}

# Add/Remove Variable Set for all specified projects
foreach ($project in $projects) {
    $project.IncludedLibraryVariableSetIds.Remove($libraryVariableSet.Id)
    $repository.Projects.Modify($project)
}