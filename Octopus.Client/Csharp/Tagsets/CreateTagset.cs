// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "Default";
var tagsetName = "Upgrade Ring";
var tagsetDescription = "Describes which upgrade ring the tenant belongs to";

// Optional Tags to add in the format "Tag name", "Tag Color"
var optionalTags = new Dictionary<string, string>();
optionalTags.Add("Early Adopter", "#ECAD3F");
optionalTags.Add("Stable", "#36A766");

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Create or modify tagset
    var tagsetEditor = repositoryForSpace.TagSets.CreateOrModify(tagsetName, tagsetDescription);

    // Add optional tags
    foreach (var tag in optionalTags)
    {
        tagsetEditor.AddOrUpdateTag(tag.Key, "", tag.Value);
    }
    tagsetEditor.Save();
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}