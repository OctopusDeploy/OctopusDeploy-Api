package main

import (
	"fmt"
	"log"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL := os.Args[1]
	space := os.Args[2]
	name := os.Args[3]

	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	octopusAuth(octopusURL, APIKey, space)
	CreateLifecycle(octopusURL, APIKey, space, name)

}

func octopusAuth(octopusURL, apiKey, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, apiKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateLifecycle(octopusURL, APIKey, space, name string) *model.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space)
	lifecycle, err := model.NewLifecycle(name)

	if err != nil {
		log.Println(err)
	}

	client.Lifecycles.Add(lifecycle)

	return lifecycle
}
