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

    public string ScopedUserRoles
    {
        get;set;
    }

    public string AD_Upn
    {
        get;
        set;
    }

    public string AD_Sam
    {
        get;
        set;
    }

    public string AD_Email
    {
        get;
        set;
    }

    public string AAD_Dn
    {
        get;
        set;
    }

    public string AAD_Email
    {
        get;
        set;
    }
}

// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
string csvExportPath = "path:\\to\\users.csv";
bool includeUserRoles = true;
bool includeActiveDirectoryDetails = false;
bool includeAzureActiveDirectoryDetails = true;
bool includeInactiveUsers = false;

System.Collections.Generic.List<UserDetails> usersList = new System.Collections.Generic.List<UserDetails>();

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get all users
var users = repository.Users.FindAll();

// Loop through users
if (!includeInactiveUsers)
    users = users.Where(u => u.IsActive == true).ToList();
foreach (var user in users)
{
    // Get basic details
    UserDetails userDetails = new UserDetails();
    userDetails.Id = user.Id;
    userDetails.Username = user.Username;
    userDetails.DisplayName = user.DisplayName;
    userDetails.IsActive = user.IsActive;
    userDetails.IsService = user.IsService;
    userDetails.EmailAddress = user.EmailAddress;

    // Check to see if userroles are included
    if (includeUserRoles)
    {
        var userTeamNames = repository.UserTeams.Get(user);

        foreach (var teamName in userTeamNames)
        {
            var team = repository.Teams.Get(teamName.Id);
            
            foreach (var role in repository.Teams.GetScopedUserRoles(team))
            {
                userDetails.ScopedUserRoles += string.Format("{0} ({1})|", (repository.UserRoles.Get(role.UserRoleId)).Name, (repository.Spaces.Get(role.SpaceId)));
            }
        }
    }

    if(includeActiveDirectoryDetails)
    {
        var activeDirectoryDetails = user.Identities.FirstOrDefault(i => i.IdentityProviderName == "Active Directory");
        if (null != activeDirectoryDetails)
        {
            userDetails.AD_Upn = activeDirectoryDetails.Claims["upn"].Value;
            userDetails.AD_Sam = activeDirectoryDetails.Claims["sam"].Value;
            userDetails.AD_Email = activeDirectoryDetails.Claims["email"].Value;
        }
    }

    if (includeAzureActiveDirectoryDetails)
    {
        var azureActiveDirectoryDetails = user.Identities.FirstOrDefault(i => i.IdentityProviderName == "Azure AD");
        if (null != azureActiveDirectoryDetails)
        {
            userDetails.AAD_Dn = azureActiveDirectoryDetails.Claims["dn"].Value;
            userDetails.AAD_Email = azureActiveDirectoryDetails.Claims["email"].Value;
        }
    }

    usersList.Add(userDetails);
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