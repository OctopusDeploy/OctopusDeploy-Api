var endpoint = new OctopusServerEndpoint("http://localhost");
var repository = new OctopusRepository(endpoint);
repository.Users.SignIn("Admin", "foo");

var mySet = repository.LibraryVariableSets.FindByName("MySet");
var projectNames = repository.Projects.GetAll().Where(p => p.IncludedLibraryVariableSetIds.Contains(mySet.Id)).Select(p => p.Name);
