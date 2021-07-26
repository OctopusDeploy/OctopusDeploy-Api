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
	projectGroupName := "MyProjectGroup"
	projectGroupDescription := "My description"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Create project group object
	projectGroup := octopusdeploy.NewProjectGroup(projectGroupName)
	projectGroup.Description = projectGroupDescription
	projectGroup.EnvironmentIDs = nil
	projectGroup.RetentionPolicyID = octopusdeploy.NewDisplayInfo().Label

	// Create project group
	client.ProjectGroups.Add(projectGroup)
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