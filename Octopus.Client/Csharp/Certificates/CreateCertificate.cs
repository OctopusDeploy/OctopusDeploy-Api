// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string pfxFilePath = "path\\to\\pfxfile.pfx";
string pfxFilePassword = "PFX-file-password";
string certificateName = "MyCertificate";
string spaceName = "default";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);
    
    // Convert file to base64
    string base64Certificate = Convert.ToBase64String(System.IO.File.ReadAllBytes(pfxFilePath));

    // Create certificate object
    Octopus.Client.Model.CertificateResource octopusCertificate = new CertificateResource(certificateName, base64Certificate, pfxFilePassword);
    repositoryForSpace.Certificates.Create(octopusCertificate);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}