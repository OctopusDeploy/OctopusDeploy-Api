package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {
	spaceId := "" // Update if authentication is in a different space
	newSpaceName := "MyNewSpace"

	apiURL, err := url.Parse("https://youroctourl")
	if err != nil {
		log.Println(err)
	}

	APIKey := "API-YOURAPIKEY"
	spaceManagersTeamMembers := []string{}                // This or spaceManagerTeams must contain a value
	spaceManagerTeams := []string{"teams-administrators"} // This or spaceManagersTeamMembers must contain a value, "teams-administrators" is the Octopus Administrators team
	environments := []string{"Development", "Test", "Production"}

	octopusAuth(apiURL, APIKey, spaceId) // Though blank, spaceId is required to be passed, blank = Default
	space := CreateSpace(apiURL, APIKey, spaceId, newSpaceName, spaceManagersTeamMembers[:], spaceManagerTeams[:])

	for i := 0; i < len(environments); i++ {
		CreateEnvironment(apiURL, APIKey, space, environments[i])
	}
}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateSpace(octopusURL *url.URL, APIKey, spaceId string, spaceName string, spaceManagersTeamMembers []string, spaceManagersTeams []string) *octopusdeploy.Space {
	client := octopusAuth(octopusURL, APIKey, spaceId)
	Space := octopusdeploy.NewSpace(spaceName)

	// Loop through team members array
	for i := 0; i < len(spaceManagersTeamMembers); i++ {
		Space.SpaceManagersTeamMembers = append(Space.SpaceManagersTeamMembers, spaceManagersTeamMembers[i])
	}

	// Loop through teams array
	for i := 0; i < len(spaceManagersTeams); i++ {
		Space.SpaceManagersTeams = append(Space.SpaceManagersTeams, spaceManagersTeams[i])
	}

	fmt.Println("Creating space: " + spaceName)

	Space, err := client.Spaces.Add(Space)

	if err != nil {
		log.Println(err)
	}

	return Space
}

func CreateEnvironment(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, environmentName string) {
	// Create client object
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Create new Environment object
	environment := octopusdeploy.NewEnvironment(environmentName)

	fmt.Println("Creating environment: " + environmentName)

	// Add to space
	environment, err := client.Environments.Add(environment)

	if err != nil {
		log.Println(err)
	}
}