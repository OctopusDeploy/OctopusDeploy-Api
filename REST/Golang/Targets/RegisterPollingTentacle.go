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
	hostName := "MyPollingTentacle"
	environments := []string{"Development", "Test"}
	roles := []string{"MyRole"}
	tentacleThumbprint := "PollingTentacleThumbprint"
	tentacleIdentifier := "PollingTentacleIdentifier"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Creat client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get the environment ids
	environmentIds := GetEnvironmentIds(client, environments)
	pollingUrl, err := url.Parse("poll://" + tentacleIdentifier + "/")
	if err != nil {
		log.Println(err)
	}

	newDeploymentTargetEndPoint := octopusdeploy.NewPollingTentacleEndpoint(pollingUrl, tentacleThumbprint)
	newDeploymentTargetEndPoint.CommunicationStyle = "TentacleActive"

	newDeploymentTarget := octopusdeploy.NewDeploymentTarget(hostName, newDeploymentTargetEndPoint, environmentIds, roles)

	machine, err := client.Machines.Add(newDeploymentTarget)
	if err != nil {
		log.Println(err)
	}

	fmt.Println(machine)
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

func GetEnvironmentIds(client *octopusdeploy.Client, environmentNames []string) []string {
	environmentIds := []string{}

	for _, environmentName := range environmentNames {
		environment, err := client.Environments.GetByName(environmentName)
		if err != nil {
			log.Println(err)
		}

		environmentIds = append(environmentIds, environment[0].ID)
	}

	return environmentIds
}