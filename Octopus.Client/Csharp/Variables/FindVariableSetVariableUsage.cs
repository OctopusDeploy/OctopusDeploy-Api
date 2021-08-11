// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System.Linq;

class VariableResult
{
    // Define private variables

    public string Project
    {
        get;
        set;
    }

    public string MatchType
    {
        get; set;
    }

    public string Context
    {
        get; set;
    }

    public string Property
    {
        get; set;
    }

    public string AdditionalContext
    {
        get; set;
    }

    public string Link
    {
        get;
        set;
    }

    public string VariableSetVariable
    {
        get;set;
    }
}

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
var spaceName = "Default";
string variableSetVariableUsagesToFind = "My-Variable-Set";
bool searchDeploymentProcess = true;
bool searchRunbookProcess = true;
string csvExportPath = "path:\\to\\variable.csv";

System.Collections.Generic.List<VariableResult> variableTracking = new System.Collections.Generic.List<VariableResult>();

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space repository
var space = repository.Spaces.FindByName(spaceName);
var repositoryForSpace = client.ForSpace(space);

// Get library set
var librarySet = repositoryForSpace.LibraryVariableSets.FindByName(variableSetVariableUsagesToFind);

// Get variables
var variableSet = repositoryForSpace.VariableSets.Get(librarySet.VariableSetId);
var variables = variableSet.Variables;

Console.WriteLine(string.Format("Looking for usages of variables from variable set {0} in space {1}", variableSetVariableUsagesToFind, space.Name));

// Get all projects
var projects = repositoryForSpace.Projects.GetAll();

// Loop through projects
foreach (var project in projects)
{
    Console.WriteLine(string.Format("Checking {0}", project.Name));

    // Get the project variable set
    var projectVariableSet = repositoryForSpace.VariableSets.Get(project.VariableSetId);

    // Loop through variables
    foreach (var variable in variables)
    {
        var matchingValueVariables = projectVariableSet.Variables.Where(v => v.Value != null && v.Value.ToLower().Contains(variable.Name.ToLower()));

        if (matchingValueVariables != null)
        {
            foreach (var match in matchingValueVariables)
            {
                VariableResult result = new VariableResult();
                result.Project = project.Name;
                result.MatchType = "Referenced Project Variable";
                result.VariableSetVariable = variable.Name;
                result.Context = match.Name;
                result.Property = null;
                result.AdditionalContext = match.Value;
                result.Link = project.Links["Variables"];

                //if (!variableTracking.Contains(result))
                if (!variableTracking.Any(r => r.Project == result.Project && r.MatchType == result.MatchType && r.VariableSetVariable == result.VariableSetVariable && r.Context == result.Context && r.Property == result.Property && r.AdditionalContext == result.AdditionalContext && r.Link == result.Link))
                {
                    variableTracking.Add(result);
                }
            }
        }
    }

    if (searchDeploymentProcess)
    {
        if (!project.IsVersionControlled)
        {
            // Get deployment process
            var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

            // Loop through steps
            foreach (var step in deploymentProcess.Steps)
            {
                // Loop through actions
                foreach (var action in step.Actions)
                {
                    // Loop through properties
                    foreach (var property in action.Properties.Keys)
                    {
                        // Loop through variables
                        foreach (var variable in variables)
                        {
                            if (action.Properties[property].Value != null && action.Properties[property].Value.ToLower().Contains(variable.Name.ToLower()))
                            {
                                VariableResult result = new VariableResult();
                                result.Project = project.Name;
                                result.MatchType = "Step";
                                result.VariableSetVariable = variable.Name;
                                result.Context = step.Name;
                                result.Property = property;
                                result.AdditionalContext = null;
                                result.Link = string.Format("{0}{1}/deployments/process/steps?actionid={2}", octopusURL, project.Links["Web"], action.Id);

                                //if (!variableTracking.Contains(result))
                                if (!variableTracking.Any(r => r.Project == result.Project && r.MatchType == result.MatchType && r.VariableSetVariable == result.VariableSetVariable && r.Context == result.Context && r.Property == result.Property && r.AdditionalContext == result.AdditionalContext && r.Link == result.Link))
                                {
                                    variableTracking.Add(result);
                                }
                            }
                        }                                    
                    }
                }
            }
        }
        else
        {
            Console.WriteLine(string.Format("{0} is version controlled, skipping searching the deployment process.", project.Name));
        }
    }

    if (searchRunbookProcess)
    {
        // Get project runbooks
        var runbooks = repositoryForSpace.Projects.GetAllRunbooks(project);

        // Loop through runbooks
        foreach (var runbook in runbooks)
        {
            // Get runbook process
            var runbookProcess = repositoryForSpace.RunbookProcesses.Get(runbook.RunbookProcessId);

            // Loop through steps
            foreach (var step in runbookProcess.Steps)
            {
                foreach (var action in step.Actions)
                {
                    foreach (var property in action.Properties.Keys)
                    {
                        foreach (var variable in variables)
                        {
                            if (action.Properties[property].Value != null && action.Properties[property].Value.ToLower().Contains(variable.Name.ToLower()))
                            {
                                VariableResult result = new VariableResult();
                                result.Project = project.Name;
                                result.MatchType = "Runbook Step";
                                result.VariableSetVariable = variable.Name;
                                result.Context = runbook.Name;
                                result.Property = property;
                                result.AdditionalContext = step.Name;
                                result.Link = string.Format("{0}{1}/operations/runbooks/{2}/process/{3}/steps?actionId={4}", octopusURL, project.Links["Web"], runbook.Id, runbookProcess.Id, action.Id);

                                //if (!variableTracking.Contains(result))
                                if (!variableTracking.Any(r => r.Project == result.Project && r.MatchType == result.MatchType && r.VariableSetVariable == result.VariableSetVariable && r.Context == result.Context && r.Property == result.Property && r.AdditionalContext == result.AdditionalContext && r.Link == result.Link))
                                {
                                    variableTracking.Add(result);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

Console.WriteLine(string.Format("Found {0} results", variableTracking.Count.ToString()));

if (variableTracking.Count > 0)
{
    foreach (var result in variableTracking)
    {
        System.Collections.Generic.List<string> row = new System.Collections.Generic.List<string>();
        System.Collections.Generic.List<string> header = new System.Collections.Generic.List<string>();
        bool isFirstRow = false;
        if (variableTracking.IndexOf(result) == 0)
        {
            isFirstRow = true;
        }

        foreach (var property in result.GetType().GetProperties())
        {
            Console.WriteLine(string.Format("{0}: {1}", property.Name, property.GetValue(result)));
            if (isFirstRow)
            {
                header.Add(property.Name);
            }
            else
            {
                row.Add((property.GetValue(result) == null ? string.Empty : property.GetValue(result).ToString()));
            }
        }

        if (!string.IsNullOrWhiteSpace(csvExportPath))
        {
            using (System.IO.StreamWriter csvFile = new System.IO.StreamWriter(csvExportPath, true))
            {
                if (isFirstRow)
                {
                    // Write header
                    csvFile.WriteLine(string.Join(",", header.ToArray()));
                }
                csvFile.WriteLine(string.Join(",", row.ToArray()));
            }
        }
    }
}
}