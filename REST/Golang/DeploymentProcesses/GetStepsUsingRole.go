package main

import (
	"fmt"
	"log"
	"net/url"
	"strings"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	roleName := "MyRole"

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get space specific client
	client = octopusAuth(apiURL, APIKey, space.ID)

	// Get all projects in space
	projects, err := client.Projects.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Loop through projects
	for _, project := range projects {
		if !project.IsVersionControlled {
			// Get project deployment process
			deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)
			if err != nil {
				log.Println(err)
			}

			// Loop through steps
			for _, step := range deploymentProcess.Steps {
				// Check to see if step is scoped to role
				if _, found := step.Properties["Octopus.Action.TargetRoles"]; found {
					roles := strings.Split(step.Properties["Octopus.Action.TargetRoles"].Value, ",")
					if arrayContains(roles, roleName) {
						fmt.Printf("Step %[1]s of project %[2]s is using role %[3]s", step.Name, project.Name, roleName)
					}
				}
			}
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

func arrayContains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
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