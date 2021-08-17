#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System.Linq;

class UserDetails
{
    // Define private variables

    public string Id
    {
        get;
        set;
    }

    public string Username
    {
        get; set;
    }

    public string DisplayName
    {
        get; set;
    }

    public bool IsActive
    {
        get; set;
    }

    public bool IsService
    {
        get; set;
    }

    public string EmailAddress
    {
        get;
        set;
    }

    public string Permissions
    {
        get;set;
    }
}

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
string csvExportPath = "path:\\to\\editpermissions.csv";

System.Collections.Generic.List<UserDetails> usersList = new System.Collections.Generic.List<UserDetails>();

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get all users
var users = repository.Users.FindAll();

// Loop through users
foreach (var user in users)
{
    System.Collections.Generic.List<string> editPermissions = new System.Collections.Generic.List<string>();

    var userPermissions = repository.UserPermissions.Get(user);

    // Loop through space permissions
    foreach (var spacePermission in userPermissions.SpacePermissions)
    {
        if (spacePermission.Key.ToString().ToLower().Contains("create") || spacePermission.Key.ToString().ToLower().Contains("delete") || spacePermission.Key.ToString().ToLower().Contains("edit"))
        {
            editPermissions.Add(spacePermission.Key.ToString());
        }
    }

    if (editPermissions.Count > 0)
    {
        // Get basic details
        UserDetails userDetails = new UserDetails();
        userDetails.Id = user.Id;
        userDetails.Username = user.Username;
        userDetails.DisplayName = user.DisplayName;
        userDetails.IsActive = user.IsActive;
        userDetails.IsService = user.IsService;
        userDetails.EmailAddress = user.EmailAddress;
        userDetails.Permissions = (String.Join("|", editPermissions.ToArray()));

        usersList.Add(userDetails);
    }
}

Console.WriteLine(string.Format("Found {0} results", usersList.Count.ToString()));

if (usersList.Count > 0)
{
    foreach (var result in usersList)
    {
        System.Collections.Generic.List<string> row = new System.Collections.Generic.List<string>();
        System.Collections.Generic.List<string> header = new System.Collections.Generic.List<string>();
        bool isFirstRow = false;
        if (usersList.IndexOf(result) == 0)
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