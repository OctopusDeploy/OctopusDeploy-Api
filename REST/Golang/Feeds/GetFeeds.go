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

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get all spaces
	space, err := client.Spaces.GetByName(spaceName)

	// Get space specific client
	client = octopusAuth(apiURL, APIKey, space.ID)

	// Get all feeds
	feeds, err := client.Feeds.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Display all feeds
	for _, feed := range feeds {
		fmt.Printf("%[1]s: %[2]s - %[3]s \n", feed.GetID(), feed.GetName(), feed.GetFeedType())
	}
}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}