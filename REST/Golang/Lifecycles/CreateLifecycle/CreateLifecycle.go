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

	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	octopusAuth(octopusURL, APIKey, space)
	CreateLifecycle(octopusURL, APIKey, space, name)

}

func octopusAuth(octopusURL *url.URL, apiKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, apiKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateLifecycle(octopusURL *url.URL, APIKey, space, name string) *octopusdeploy.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space)
	lifecycle := octopusdeploy.NewLifecycle(name)

	client.Lifecycles.Add(lifecycle)

	return lifecycle
}
