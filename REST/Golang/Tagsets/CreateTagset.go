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
	tagsetName := "MyTagset"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get tagset
	tagset := GetTagSet(client, tagsetName)

	if tagset == nil {
		// Create new tagset
		tagset = octopusdeploy.NewTagSet(tagsetName)

		// Create new tag
		tag := octopusdeploy.Tag{
			Name:        "MyTag",
			Color:       "#ECAD3F",
			Description: "My tag description",
		}

		// Add to set
		tagset.Tags = append(tagset.Tags, tag)

		// Add to server
		client.TagSets.Add(tagset)
	} else {
		fmt.Println("Tagset " + tagsetName + " already exists!")
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

func GetTagSet(client *octopusdeploy.Client, tagsetName string) *octopusdeploy.TagSet {
	// Get tagsets
	tagSet, err := client.TagSets.GetByName(tagsetName)

	if err != nil {
		log.Println(err)
	}

	return tagSet
}