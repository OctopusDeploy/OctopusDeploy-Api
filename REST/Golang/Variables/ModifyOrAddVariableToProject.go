package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	variable := octopusdeploy.NewVariable("MyVariable")
	variable.IsSensitive = false
	variable.Type = "String"
	variable.Value = "MyValue"
	projectName := "MyProject"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get project reference
	project := GetProject(apiURL, APIKey, space, projectName)

	// Get project variables
	projectVariables := GetProjectVariables(apiURL, APIKey, space, project)
	variableFound := false

	for i := 0; i < len(projectVariables.Variables); i++ {
		if projectVariables.Variables[i].Name == variable.Name {
			projectVariables.Variables[i].IsSensitive = variable.IsSensitive
			projectVariables.Variables[i].Type = variable.Type
			projectVariables.Variables[i].Value = variable.Value

			variableFound = true
			break
		}
	}

	if !variableFound {
		projectVariables.Variables = append(projectVariables.Variables, variable)
	}

	// Update target
	client := octopusAuth(apiURL, APIKey, space.ID)
	client.Variables.Update(project.ID, projectVariables)
}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func GetSpace(octopusURL *url.URL, APIKey string, spaceName string) *octopusdeploy.Space {
	client := octopusAuth(octopusURL, APIKey, "")

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
}

func GetProject(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, projectName string) *octopusdeploy.Project {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get project
	project, err := client.Projects.GetByName(projectName)

	if err != nil {
		log.Println(err)
	}

	if project != nil {
		fmt.Println("Retrieved project " + project.Name)
	} else {
		fmt.Println("Project " + projectName + " not found!")
	}

	return project
}

func GetProjectVariables(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, project *octopusdeploy.Project) octopusdeploy.VariableSet {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get project variables
	projectVariables, err := client.Variables.GetAll(project.ID)

	if err != nil {
		log.Println(err)
	}

	return projectVariables
}