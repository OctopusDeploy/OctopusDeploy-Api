package main

import (
	"log"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
)

func main() {
	octopusURL := os.Args[1]
	apiKey := os.Args[2]
	space := os.Args[3]
	name := os.Args[4]
	projectID := os.Args[5]

	octopusAuth(octopusURL, apiKey, space)
	CreateChannel(octopusURL, apiKey, space, name, projectID)

}

func octopusAuth(octopusURL string, apiKey string, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, apiKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateChannel(octopusURL, apiKey, space, name, projectID string) *model.Channel {
	client := octopusAuth(octopusURL, apiKey, space)
	Channel, err := model.NewChannel(name, projectID, "New channel")

	if err != nil {
		log.Println(err)
	}

	client.Channels.Add(Channel)

	return Channel
}
