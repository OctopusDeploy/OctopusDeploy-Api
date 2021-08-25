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

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get all projects
	projects, err := client.Projects.GetAll()

	if err != nil {
		log.Println(err)
	}

	// Loop through projects
	for i := 0; i < len(projects); i++ {
		if !projects[i].IsVersionControlled {

			// Get deployment process
			deploymentProcess := GetDeploymentProcess(client, projects[i])

			// Check for steps
			if deploymentProcess == nil || deploymentProcess.Steps == nil || len(deploymentProcess.Steps) == 0 {
				// Delete project
				fmt.Println("Deleting " + projects[i].Name)
				client.Projects.DeleteByID(projects[i].ID)
			}
		} else {
			fmt.Println(projects[i].Name + " is using version control, skipping")
		}
	}

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

func GetDeploymentProcess(client *octopusdeploy.Client, project *octopusdeploy.Project) *octopusdeploy.DeploymentProcess {
	deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)

	if err != nil {
		log.Println(err)
	}

	return deploymentProcess
}