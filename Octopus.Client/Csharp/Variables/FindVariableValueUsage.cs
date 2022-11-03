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

    public string VariableSet
    {
        get;
        set;
    }
}

var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURKEY";
var spaceName = "Default";
string variableValueToFind = "MyValue";
string csvExportPath = "path:\\to\\variable.csv";

System.Collections.Generic.List<VariableResult> variableTracking = new System.Collections.Generic.List<VariableResult>();

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space repository
var space = repository.Spaces.FindByName(spaceName);
var repositoryForSpace = client.ForSpace(space);

Console.WriteLine(string.Format("Looking for usages of variable value {0} in space {1}", variableValueToFind, space.Name));

// Get all variable sets
var variableSets = repositoryForSpace.LibraryVariableSets.FindAll();

// Loop through variable sets
foreach (var variableSet in variableSets)
{
    Console.WriteLine(string.Format("Checking variable set: {0}", variableSet.Name));

    // Get the variables
    var variables = repositoryForSpace.VariableSets.Get(variableSet.VariableSetId);

    // Get matches
    var matchingValueVariable = variables.Variables.Where(v => v.Value != null && v.Value.ToLower().Contains(variableValueToFind.ToLower()));

    if (matchingValueVariable != null)
    {
        foreach (var match in matchingValueVariable)
        {
            VariableResult result = new VariableResult();
            result.Project = null;
            result.VariableSet = variableSet.Name;
            result.MatchType = "Value in Library Set";
            result.Context = match.Value;
            result.AdditionalContext = match.Name;

            if (!variableTracking.Contains(result))
            {
                variableTracking.Add(result);
            }
        }
    }
}

// Get all projects
var projects = repositoryForSpace.Projects.GetAll();

// Loop through projects
foreach (var project in projects)
{
    Console.WriteLine(string.Format("Checking {0}", project.Name));

    // Get the project variable set
    var projectVariableSet = repositoryForSpace.VariableSets.Get(project.VariableSetId);

    var matchingNameVariable = projectVariableSet.Variables.Where(v => v.Value != null && v.Value.ToLower().Contains(variableValueToFind.ToLower()));

    // Match on name
    if (matchingNameVariable != null)
    {
        // Loop through results
        foreach (var match in matchingNameVariable)
        {
            VariableResult result = new VariableResult();
            result.Project = project.Name;
            result.VariableSet = null;
            result.MatchType = "Named Project Variable";
            result.Context = match.Value;
            result.Property = null;
            result.AdditionalContext = match.Name;

            if (!variableTracking.Contains(result))
            {
                variableTracking.Add(result);
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