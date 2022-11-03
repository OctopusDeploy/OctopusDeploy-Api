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
        get;set;
    }

    public string Property
    {
        get;set;
    }

    public string AdditionalContext
    {
        get;set;
    }

    public string Link
    {
        get;
        set;
    }
}

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
var spaceName = "Default";
string variableToFind = "MyProject.Variable";
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

Console.WriteLine(string.Format("Looking for usages of variable named {0} in space {1}", variableToFind, space.Name));

// Get all projects
var projects = repositoryForSpace.Projects.GetAll();

// Loop through projects
foreach (var project in projects)
{
    Console.WriteLine(string.Format("Checking {0}", project.Name));

    // Get the project variable set
    var projectVariableSet = repositoryForSpace.VariableSets.Get(project.VariableSetId);

    var matchingNameVariable = projectVariableSet.Variables.Where(v => v.Name.ToLower().Contains(variableToFind.ToLower()));

    // Match on name
    if (matchingNameVariable != null)
    {
        // Loop through results
        foreach (var match in matchingNameVariable)
        {
            VariableResult result = new VariableResult();
            result.Project = project.Name;
            result.MatchType = "Named Project Variable";
            result.Context = match.Name;
            result.Property = null;
            result.AdditionalContext = match.Value;
            result.Link = project.Links["Variables"];

            if (!variableTracking.Contains(result))
            {
                variableTracking.Add(result);
            }
        }
    }

    // Match on value
    var matchingValueVariable = projectVariableSet.Variables.Where(v => v.Value != null && v.Value.ToLower().Contains(variableToFind.ToLower()));

    if (matchingValueVariable != null)
    {
        // Loop through results
        foreach (var match in matchingValueVariable)
        {
            VariableResult result = new VariableResult();
            result.Project = project.Name;
            result.MatchType = "Referenced Project Variable";
            result.Context = match.Name;
            result.Property = null;
            result.AdditionalContext = match.Value;
            result.Link = project.Links["Variables"];

            if (!variableTracking.Contains(result))
            {
                variableTracking.Add(result);
            }
        }
    }

    if (searchDeploymentProcess)
    {
        if(!project.IsVersionControlled)
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
                        if (action.Properties[property].Value != null && action.Properties[property].Value.ToLower().Contains(variableToFind.ToLower()))
                        {
                            VariableResult result = new VariableResult();
                            result.Project = project.Name;
                            result.MatchType = "Step";
                            result.Context = step.Name;
                            result.Property = property;
                            result.AdditionalContext = null;
                            result.Link = string.Format("{0}{1}/deployments/process/steps?actionid={2}", octopusURL, project.Links["Web"], action.Id);

                            if (!variableTracking.Contains(result))
                            {
                                variableTracking.Add(result);
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
                        if (action.Properties[property].Value != null && action.Properties[property].Value.ToLower().Contains(variableToFind.ToLower()))
                        {
                            VariableResult result = new VariableResult();
                            result.Project = project.Name;
                            result.MatchType = "Runbook Step";
                            result.Context = runbook.Name;
                            result.Property = property;
                            result.AdditionalContext = step.Name;
                            result.Link = string.Format("{0}{1}/operations/runbooks/{2}/process/{3}/steps?actionId={4}", octopusURL, project.Links["Web"], runbook.Id, runbookProcess.Id, action.Id);

                            if (!variableTracking.Contains(result))
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

Console.WriteLine(string.Format("Found {0} results", variableTracking.Count.ToString()));

if (variableTracking.Count > 0)
{
    foreach (var result in variableTracking)
    {
        System.Collections.Generic.List<string> header = new System.Collections.Generic.List<string>();
        System.Collections.Generic.List<string> row = new System.Collections.Generic.List<string>();

        var isFirstRow = variableTracking.IndexOf(result) == 0;
        var properties = result.GetType().GetProperties();

        foreach (var property in properties)
        {
            Console.WriteLine(string.Format("{0}: {1}", property.Name, property.GetValue(result)));
            if (isFirstRow)
            {
                header.Add(property.Name);
            }
            row.Add((property.GetValue(result) == null ? string.Empty : property.GetValue(result).ToString()));
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
                // Write result
                csvFile.WriteLine(string.Join(",", row.ToArray()));
            }
        }
    }
}