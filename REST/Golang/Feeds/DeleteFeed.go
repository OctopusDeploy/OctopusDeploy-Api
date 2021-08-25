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
	feedName := "MyFeed"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get feed id
	feedId := GetFeedId(client, feedName)

	if feedId != "" {
		// Delete the feed
		client.Feeds.DeleteByID(feedId)
	} else {
		fmt.Println(feedName + " not found!")
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

func GetFeedId(client *octopusdeploy.Client, feedName string) string {
	// Get the feed
	feedQuery := octopusdeploy.FeedsQuery{
		PartialName: feedName,
	}

	feeds, err := client.Feeds.Get(feedQuery)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(feeds.Items); i++ {
		if feeds.Items[i].GetName() == feedName {
			return feeds.Items[i].GetID()
		}
	}

	return ""
}