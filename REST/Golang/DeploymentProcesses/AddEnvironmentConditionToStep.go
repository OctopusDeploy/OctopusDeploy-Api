package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourUrl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	environmentNames := []string{"Development", "Production"}
	environments := []octopusdeploy.Environment{}
	projectName := "MyProject"
	stepName := "MyStep"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get reference to project
	project := GetProject(apiURL, APIKey, space, projectName)
	deploymentProcess := GetProjectDeploymentProcess(apiURL, APIKey, space, project)

	// Get references to environments
	for i := 0; i < len(environmentNames); i++ {
		environment := GetEnvironment(apiURL, APIKey, space, environmentNames[i])
		environments = append(environments, *environment)
	}

	// Loop through deployment process
	for i := 0; i < len(deploymentProcess.Steps); i++ {
		// Check to see if it's the step we want
		if deploymentProcess.Steps[i].Name == stepName {
			// Loop through actions
			for j := 0; j < len(deploymentProcess.Steps[i].Actions); j++ {
				// Loop through environments to add
				for e := 0; e < len(environments); e++ {
					if !contains(deploymentProcess.Steps[i].Actions[j].Environments, environments[e].ID) {
						// Add environment
						fmt.Println("Adding " + environments[e].Name + " to step " + deploymentProcess.Steps[i].Name)
						deploymentProcess.Steps[i].Actions[j].Environments = append(deploymentProcess.Steps[i].Actions[j].Environments, environments[e].ID)
					}
				}
			}
		}
	}

	// Update deployment process
	client := octopusAuth(apiURL, APIKey, space.ID)
	client.DeploymentProcesses.Update(deploymentProcess)
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

	spaceQuery := octopusdeploy.SpacesQuery{
		Name: spaceName,
	}

	// Get specific space object
	spaces, err := client.Spaces.Get(spaceQuery)

	if err != nil {
		log.Println(err)
	}

	for _, space := range spaces.Items {
		if space.Name == spaceName {
			return space
		}
	}

	return nil
}

func GetEnvironment(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, EnvironmentName string) *octopusdeploy.Environment {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get environment
	environmentsQuery := octopusdeploy.EnvironmentsQuery {
		Name: environmentName,		
	}
	environments, err := client.Environments.Get(environmentsQuery)
	if err != nil {
		log.Println(err)
	}

	// Loop through results
	for _, environment := range environments.Items {
		if environment.Name == environmentName {
			return environment
		}
	}

	return nil
}

func GetProject(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, ProjectName string) *octopusdeploy.Project {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	projectsQuery := octopusdeploy.ProjectsQuery {
		Name: ProjectName
	}

	projects, err := client.Projects.Get(projectsQuery)
	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved project " + project.Name)
	}

	for _, project := range projects {
		if project.Name == ProjectName {
			return project
		}
	}

	return nil
}

func GetProjectDeploymentProcess(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, project *octopusdeploy.Project) *octopusdeploy.DeploymentProcess {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved deployment process for project " + project.Name)
	}

	return deploymentProcess
}

func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}