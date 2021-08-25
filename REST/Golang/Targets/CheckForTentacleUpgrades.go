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

	client := octopusAuth(apiURL, APIKey, space.ID)
	allTargets, err := client.Machines.GetAll()
	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(allTargets); i++ {
		fmt.Println("Checking target: " + allTargets[i].Name)
		fmt.Println("Health Status: " + allTargets[i].HealthStatus)
		fmt.Println("Status: " + allTargets[i].Status)
	}

	allWorkers, err := client.Workers.GetAll()
	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(allWorkers); i++ {
		fmt.Println("Checking target: " + allWorkers[i].Name)
		fmt.Println("Health Status: " + allWorkers[i].HealthStatus)
		fmt.Println("Status: " + allWorkers[i].Status)
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