void Main()
{
	var apiKey = "API-YOUR_KEY";

	var octopusServer = new Octopus.Client.OctopusServerEndpoint("http://your.octopus.instance", apiKey);
	var repo = new Octopus.Client.OctopusRepository(octopusServer);
	var spaceToWorkIn = repo.Spaces.FindByName("Another Space");
	var spaceRepo = repo.ForSpace(spaceToWorkIn);
	
	var projectsInThisSpace = spaceRepo.Projects.GetAll();

}
