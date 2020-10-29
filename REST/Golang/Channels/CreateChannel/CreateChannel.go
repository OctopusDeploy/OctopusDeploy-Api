package main

import (
	"fmt"
	"log"
	"net/url"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL, _ := url.Parse(os.Args[1])
	space := os.Args[2]
	name := os.Args[3]
	projectID := os.Args[4]

	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	octopusAuth(octopusURL, APIKey, space)
	CreateChannel(octopusURL, APIKey, space, name, projectID)

}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateChannel(octopusURL *url.URL, APIKey, space, name, projectID string) *octopusdeploy.Channel {
	client := octopusAuth(octopusURL, APIKey, space)
	channel := octopusdeploy.NewChannel(name, projectID, "New channel")

	client.Channels.Add(channel)

	return channel
}
