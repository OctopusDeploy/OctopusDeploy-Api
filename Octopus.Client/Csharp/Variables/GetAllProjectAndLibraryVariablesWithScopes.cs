class Program
{
    static void Main(string[] args)
    {
        var endpoint = new OctopusServerEndpoint("[URL]", "[APIKey]");
        var _repository = new OctopusRepository(endpoint);

        string projectName = "[ProjectName]";
        ProjectResource project = _repository.Projects.FindOne(p => p.Name == projectName);

        var variablesList = new List<VariableViewModel>();

        //Dictionary to get Names from Ids
        Dictionary<string,string> scopeNames = _repository.Environments.FindAll().ToDictionary(x => x.Id, x => x.Name);
        _repository.Machines.FindAll().ToList().ForEach(x => scopeNames[x.Id] = x.Name);
        _repository.Projects.GetChannels(project).Items.ToList().ForEach(x => scopeNames[x.Id] = x.Name);
        _repository.DeploymentProcesses.Get(project.DeploymentProcessId).Steps.SelectMany(x=>x.Actions).ToList().ForEach(x => scopeNames[x.Id] = x.Name);


        //Get All Library Set Variables
        List<LibraryVariableSetResource> librarySets = _repository.LibraryVariableSets.FindAll();

        foreach (var libraryVariableSetResource in librarySets)
        {

            var variables = _repository.VariableSets.Get(libraryVariableSetResource.VariableSetId);
            var variableSetName = libraryVariableSetResource.Name;
            foreach (var variable in variables.Variables)
            {
                variablesList.Add(new VariableViewModel(variable, variableSetName, scopeNames));
            }

        }

        //Get All Project Variables for the Project
        var projectSets = _repository.VariableSets.Get(project.VariableSetId);

        foreach (var variable in projectSets.Variables)
        {
            variablesList.Add(new VariableViewModel(variable, projectName, scopeNames));
        }

        foreach (var vm in variablesList)
        {
            Console.WriteLine($"Name:{vm.Name} Value:{vm.Value} Scope: {vm.Scope}");
        }

        var input = Console.ReadLine();

    }
}

public class VariableViewModel
{
    //public string VariableSet { get; set; }
    public string Name { get; set; }
    public string Value { get; set; }
    public string Scope { get; set; }

    public VariableViewModel(VariableResource variable, string variableSetName, Dictionary<String, String> scopeNames)
    {
        Name = variable.Name;
        Value = variable.Value;

        var nonLookupRoles =
            variable.Scope.Where(s => s.Key != ScopeField.Environment & s.Key != ScopeField.Machine & s.Key != ScopeField.Channel & s.Key != ScopeField.Action)
                .ToDictionary(dict => dict.Key, dict => dict.Value);

        foreach (var scope in nonLookupRoles)
        {
            if (string.IsNullOrEmpty(Scope))
                Scope = String.Join(",", scope.Value, Scope);
        }

        var lookupRoles =
            variable.Scope.Where(s => s.Key == ScopeField.Environment || s.Key == ScopeField.Machine || s.Key == ScopeField.Channel || s.Key == ScopeField.Action)
                .ToDictionary(dict => dict.Key, dict => dict.Value);

        foreach (var role in lookupRoles)
        {
            foreach (var scope in role.Value)
            {
                Scope = String.Join(",", scopeNames[scope], Scope);
            }
        }

    }
}