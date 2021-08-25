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
	targetName := "MyTargetName"
	roleName := "MyRoleName"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get deployment target
	target := GetTarget(apiURL, APIKey, space, targetName)

	// Add role to target
	target.Roles = append(target.Roles, roleName)

	// Update target
	client := octopusAuth(apiURL, APIKey, space.ID)
	client.Machines.Update(target)
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

func GetTarget(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, targetName string) *octopusdeploy.DeploymentTarget {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get target
	deploymentTargets, err := client.Machines.GetByName(targetName)

	if err != nil {
		log.Println(err)
	}

	// Loop through returned targets
	for i := 0; i < len(deploymentTargets); i++ {
		if deploymentTargets[i].Name == targetName {
			return deploymentTargets[i]
		}
	}

	return nil
}