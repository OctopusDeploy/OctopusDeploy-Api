package main

import (
	"fmt"

	"github.com/OctopusDeploy/go-octopusdeploy/client"
)

var (
	// Declare working variables
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"

	spaceName string = "Default"
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	// Get all Feeds
	feeds, err := client.Feeds.GetAll()

	if err != nil {
		// TODO: handle error
	}

	for _, feed := range feeds {
		fmt.Sprintln("Feed ID: %s", feed.ID)
		fmt.Sprintln("Feed Name: %s", feed.Name)
		fmt.Sprintln("Feed Type: %s", feed.FeedType)
		fmt.Println()
	}
}
