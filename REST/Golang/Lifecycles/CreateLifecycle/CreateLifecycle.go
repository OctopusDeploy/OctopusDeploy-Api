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
	spaceName := "MySpace"
	lifecycleName := "MyLifecycle"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Check to see if the lifecycle already exists
	if GetLifecycle(apiURL, APIKey, space, lifecycleName) == nil {
		lifecycle := CreateLifecycle(apiURL, APIKey, space, lifecycleName)
		fmt.Println(lifecycle.Name + " created successfully")
	} else {
		fmt.Println(lifecycleName + " already exists.")
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

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
}

func GetLifecycle(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, LifecycleName string) *octopusdeploy.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	lifecycles, err := client.Lifecycles.GetByPartialName(LifecycleName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(lifecycles); i++ {
		if lifecycles[i].Name == LifecycleName {
			return lifecycles[i]
		}
	}

	return nil
}

func CreateLifecycle(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, name string) *octopusdeploy.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space.ID)
	lifecycle := octopusdeploy.NewLifecycle(name)

	client.Lifecycles.Add(lifecycle)

	return lifecycle
}