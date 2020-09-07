static void Main(string[] args)
{
  var endpoint = new OctopusServerEndpoint("https://octopus.url", "API-XXXXXXXXXXXXXXXXXXXXXXXXXX");
  var repository = new OctopusRepository(endpoint);

  var tentacleEndpoint = new PollingTentacleEndpointResource();
  tentacleEndpoint.Thumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091"; // The certificate thumbprint of the tentacle
  tentacleEndpoint.Uri = "poll://PDMFX3BFMQ1EEB0BOU2Y/"; // A 20-character random alpha-numeric string becomes the mailbox to poll from

  var tentacle = new MachineResource();
  tentacle.Endpoint = tentacleEndpoint;
  tentacle.EnvironmentIds.Add("Environments-1");
  tentacle.Roles.Add("demo-role");
  tentacle.Name = "Demo tentacle";

  repository.Machines.Create(tentacle);
}
