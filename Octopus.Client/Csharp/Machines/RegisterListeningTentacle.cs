static void Main(string[] args)
{
  var endpoint = new OctopusServerEndpoint("http://localhost/", "API-XXXXXXXXXXXXXXXXXXXXXXXXXX");
  var repository = new OctopusRepository(endpoint);

  var tentacleEndpoint = new ListeningTentacleEndpointResource();
  tentacleEndpoint.Thumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091";
  tentacleEndpoint.Uri = "https://localhost:10933";

  var tentacle = new MachineResource();
  tentacle.Endpoint = tentacleEndpoint;
  tentacle.EnvironmentIds.Add("Environments-1");
  tentacle.Roles.Add("demo-role");
  tentacle.Name = "Demo tentacle";

  repository.Machines.Create(tentacle);
}
