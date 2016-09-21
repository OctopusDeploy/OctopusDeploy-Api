var client = new OctopusClient(new OctopusServerEndpoint(octoUrl, apiKey));
var repo = new OctopusRepository(client);

var project = repo.Projects.FindByName("MyOriginalProject");
            
var newProject = new ProjectResource
{
    Name = "MyClonedProject",
    Description = "Cloned copy",
    ProjectGroupId = project.ProjectGroupId,
    LifecycleId = project.LifecycleId
};
client.Post("~/api/projects?clone=" + project.Id, newProject);