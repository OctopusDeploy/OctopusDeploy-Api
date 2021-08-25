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
	if GetLifecycle(apiURL, APIKey, space, lifecycleName, 0) == nil {
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

func GetLifecycle(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, LifecycleName string, skip int) *octopusdeploy.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	lifecycleQuery := octopusdeploy.LifecyclesQuery {
		PartialName: LifecycleName,
	}

	lifecycles, err := client.Lifecycles.Get(lifecycleQuery)

	if err != nil {
		log.Println(err)
	}
	
	if len(lifecycles.Items) == lifecycles.ItemsPerPage {
		// call again
		lifecycle := GetLifecycle(octopusURL, APIKey, space, LifecycleName, (skip + len(lifecycles.Items)))

		if lifecycle != nil {
			return lifecycle
		}
	} else {
		// Loop through returned items
		for _, lifecycle := range lifecycles.Items {
			if lifecycle.Name == LifecycleName {
				return lifecycle
			}
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