////CONFIG////
var apiKey = "API-12345678910";
var server = "https://octopus.url";
var environmentName = "MyEnvironment";
var projectName = "MyProject";
var releaseVersion = "0.0.1";

//Add your prompted variables here
var PromptedVariablesForm = new Dictionary<string,string>{
	{ "PromptedVariable1", "foo" },
	{ "PromptedVariable2","bar"}
};

////EXECUTION////
var endpoint = new OctopusServerEndpoint(server, apiKey);
var repository = new OctopusRepository(endpoint);

var environment = repository.Environments.FindByName(environmentName);
var project = repository.Projects.FindByName(projectName);

var release = repository.Releases.FindOne(x => x.ProjectId == project.Id && x.Version == releaseVersion);
var releaseTemplate = repository.Releases.GetTemplate(release);

var promotion = releaseTemplate.PromoteTo.FirstOrDefault(x => string.Equals(x.Name, environment.Name, StringComparison.InvariantCultureIgnoreCase));

var preview = repository.Releases.GetPreview(promotion);

var formValues = new Dictionary<string, string>();
foreach (var element in preview.Form.Elements)
{
	var variableInput = element.Control as VariableValue;
	if(variableInput == null){
		continue;
	}
	
	string val;
	if(PromptedVariablesForm.TryGetValue(variableInput.Name, out val)){
		formValues.Add(element.Name, val);
	}
}

//creating the deployment object
var deployment = new DeploymentResource
{
	ReleaseId = release.Id,
	ProjectId = project.Id,
	EnvironmentId = environment.Id,
	FormValues = formValues
};

//Deploying the release in Octopus
var result = repository.Deployments.Create(deployment);
