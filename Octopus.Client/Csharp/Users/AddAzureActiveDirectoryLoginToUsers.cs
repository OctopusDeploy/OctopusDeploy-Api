// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System.Linq;
public class UserToUpdate
{
    public string OctopusUserName
    {
        get;
        set;
    }

    public string AzureEmailAddress
    {
        get;
        set;
    }

    public string AzureDisplayName
    {
        get;
        set;
    }
}

public static void AddAzureLogins(string OctopusUrl, string ApiKey, string Path = "", string OctopusUserName = "", string AzureEmailAddress = "", string AzureDisplayName = "", bool UpdateOctopusEmail = false, bool UpdateOctopusDisplayName = false, bool Force = false, bool WhatIf = false)
{
    // Display passed in information
    Console.WriteLine(string.Format("OctopusURL: {0}", OctopusUrl));
    Console.WriteLine("OctopusAPIKey: ****");
    Console.WriteLine(string.Format("OctopusUsername: {0}", OctopusUserName));
    Console.WriteLine(string.Format("AzureEmailAddress: {0}", AzureEmailAddress));
    Console.WriteLine(string.Format("AzureDisplayName: {0}", AzureDisplayName));
    Console.WriteLine(string.Format("UpdateOctopusEmailAddress: {0}", UpdateOctopusEmail.ToString()));
    Console.WriteLine(string.Format("UpdateOctopusDisplayName: {0}", UpdateOctopusDisplayName.ToString()));
    Console.WriteLine(string.Format("Force: {0}", Force.ToString()));
    Console.WriteLine(string.Format("WhatIf: {0}", WhatIf.ToString()));

    // Check to see url is emtpy
    if (!string.IsNullOrWhiteSpace(OctopusUrl))
    {
        // Remove trailing /
        OctopusUrl = OctopusUrl.TrimEnd('/');
    }

    // Create Octopus.Client objects
    var endpoint = new Octopus.Client.OctopusServerEndpoint(OctopusUrl, ApiKey);
    var repository = new Octopus.Client.OctopusRepository(endpoint);
    var client = new Octopus.Client.OctopusClient(endpoint);

    // Declare collection of users to update
    var usersToUpdate = new System.Collections.Generic.List<UserToUpdate>();

    // Test to see if path was provided
    if (string.IsNullOrWhiteSpace(Path))
    {
        if (!string.IsNullOrWhiteSpace(OctopusUserName) || !string.IsNullOrWhiteSpace(AzureEmailAddress))
        {
            // Create new user to update object
            var userToUpdate = new UserToUpdate();
            userToUpdate.AzureDisplayName = AzureDisplayName;
            userToUpdate.AzureEmailAddress = AzureEmailAddress;
            userToUpdate.OctopusUserName = OctopusUserName;

            // Add to collection
            usersToUpdate.Add(userToUpdate);
        }
    }
    else
    {
        // Read from csv
        using (var reader = new System.IO.StreamReader(Path))
        {
            while (!reader.EndOfStream)
            {
                var line = reader.ReadLine();
                var columns = line.Split(',');

                // Create new user to update object
                var userToUpdate = new UserToUpdate();
                userToUpdate.AzureDisplayName = columns[0];
                userToUpdate.AzureEmailAddress = columns[1];
                userToUpdate.OctopusUserName = columns[2];

                // Add to collection
                usersToUpdate.Add(userToUpdate);
            }
        }
    }

    // Check to see if we have anything to update
    if (usersToUpdate.Count > 0)
    {
        Console.WriteLine(string.Format("Users to update: {0}", usersToUpdate.Count));

        // Loop through collection
        foreach (var userToUpdate in usersToUpdate)
        {
            Console.WriteLine(string.Format("Searching for user {0}", userToUpdate.OctopusUserName));
            var existingOctopusUser = client.Repository.Users.FindByUsername(userToUpdate.OctopusUserName);

            // Check to see if something was returned
            if (null != existingOctopusUser)
            {
                // Check to see if it is a service account
                if (existingOctopusUser.IsService)
                {
                    Console.WriteLine(string.Format("{0} is a service account, skipping ...", userToUpdate.OctopusUserName));
                    continue;
                }

                // Check to see if user is active
                if (!existingOctopusUser.IsActive)
                {
                    Console.WriteLine(string.Format("{0} is not an active account, skipping ...", userToUpdate.OctopusUserName));
                }

                // Get existing azure identity, if exists
                var azureAdIdentity = existingOctopusUser.Identities.FirstOrDefault(i => i.IdentityProviderName == "Azure AD");

                // Check to see if something was returned
                if(null != azureAdIdentity)
                {
                    // Check to see if force update was set
                    if (Force)
                    {
                        Console.WriteLine(string.Format("Force set to true, replacing existing entries for {0}", userToUpdate.OctopusUserName));
                        azureAdIdentity.Claims["email"].Value = userToUpdate.AzureEmailAddress;
                        azureAdIdentity.Claims["dn"].Value = userToUpdate.AzureDisplayName;
                    }
                }
                else
                {
                    Console.WriteLine(string.Format("No existing AzureAD login found for user {0}", userToUpdate.OctopusUserName));

                    // Create new octopus objects
                    var newAzureIdentity = new Octopus.Client.Model.IdentityResource();
                    newAzureIdentity.IdentityProviderName = "Azure AD";

                    var newEmailClaim = new Octopus.Client.Model.IdentityClaimResource();
                    newEmailClaim.IsIdentifyingClaim = true;
                    newEmailClaim.Value = userToUpdate.AzureEmailAddress;

                    newAzureIdentity.Claims.Add("email", newEmailClaim);

                    var newDisplayNameClaim = new Octopus.Client.Model.IdentityClaimResource();
                    newDisplayNameClaim.IsIdentifyingClaim = false;
                    newDisplayNameClaim.Value = userToUpdate.AzureDisplayName;

                    newAzureIdentity.Claims.Add("dn", newDisplayNameClaim);

                    // Add identity object to user
                    var identityCollection = new System.Collections.Generic.List<Octopus.Client.Model.IdentityResource>(existingOctopusUser.Identities);
                    identityCollection.Add(newAzureIdentity);
                    existingOctopusUser.Identities = identityCollection.ToArray();
                }

                if (UpdateOctopusDisplayName && !string.IsNullOrWhiteSpace(userToUpdate.AzureDisplayName))
                {
                    Console.WriteLine(string.Format("Setting Octopus Display Name to: {0}", userToUpdate.AzureDisplayName));
                    existingOctopusUser.DisplayName = userToUpdate.AzureDisplayName;
                }

                if (UpdateOctopusEmail && !string.IsNullOrWhiteSpace(userToUpdate.AzureEmailAddress))
                {
                    Console.WriteLine(string.Format("Setting Octopus Email Address to: {0}", userToUpdate.AzureEmailAddress));
                    existingOctopusUser.EmailAddress = userToUpdate.AzureEmailAddress;
                }

                if (WhatIf)
                {
                    Console.WriteLine(string.Format("WhatIf is set to true, skipping update of user: {0}", userToUpdate.OctopusUserName));
                    Console.WriteLine(existingOctopusUser);
                }
                else
                {
                    // Update account
                    Console.WriteLine(string.Format("Updating: {0}", userToUpdate.OctopusUserName));
                    client.Repository.Users.Modify(existingOctopusUser);
                }
            }
        }
    }
}