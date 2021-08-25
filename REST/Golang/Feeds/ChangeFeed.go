package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("http://octopusserver1")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YOUR-KEY"
	spaceName := "Default"
	feedName := "TestFeed"
	newFeedName := "MyNewFeedName"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Change the feed name
	ChangeFeedName(apiURL, APIKey, space, feedName, newFeedName)
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

func ChangeFeedName(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, FeedName string, NewFeedName string) {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get current feed
	feedsQuery := octopusdeploy.FeedsQuery{
		PartialName: FeedName,
	}
	feeds, err := client.Feeds.Get(feedsQuery)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(feeds.Items); i++ {
		if feeds.Items[i].GetName() == FeedName {
			fmt.Println("Updating feed " + FeedName + " to " + NewFeedName)
			feeds.Items[i].SetName(NewFeedName)
			client.Feeds.Update(feeds.Items[i])

			break
		}
	}
}