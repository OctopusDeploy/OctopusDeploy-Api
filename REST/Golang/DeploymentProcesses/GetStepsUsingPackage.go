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
	packageId := "MyPackageId"

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
				// Loop through actions
				for _, action := range step.Actions {
					// check to see if it uses a package
					if action.Packages != nil {
						for i := 0; i < len(action.Packages); i++ {
							if action.Packages[i].PackageID == packageId {
								fmt.Printf("Step %[1]s of %[2]s is using package %[3]s \n", step.Name, project.Name, packageId)
							}
						}
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