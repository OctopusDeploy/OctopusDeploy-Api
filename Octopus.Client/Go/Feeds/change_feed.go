package main

import "github.com/OctopusDeploy/go-octopusdeploy/client"

var (
	// Declare working variables
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"

	spaceName   string = "Default"
	feedName    string = "nuget.org 3"
	newFeedName string = "nuget.org feed"
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	// Get Feed
	feed, err := client.Feeds.GetByName(feedName)

	if err != nil {
		// TODO: handle error
	}

	// Change feed name
	feed.Name = newFeedName

	// Update feed
	updatedFeed, err := client.Feeds.Update(*feed)

	if err != nil {
		// TODO: handle error
	}
}
