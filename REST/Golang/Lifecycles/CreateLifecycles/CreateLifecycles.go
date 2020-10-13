package main

import (
	"fmt"
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

	octopusAuth(octopusURL, apiKey, space)
	CreateLifecycle(octopusURL, apiKey, space, name)

}

func octopusAuth(octopusURL string, apiKey string, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, apiKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateLifecycle(octopusURL, apiKey, space, name string) *model.Lifecycle {
	client := octopusAuth(octopusURL, apiKey, space)
	lifecycle, err := model.NewLifecycle(name)

	if err != nil {
		log.Println(err)
	}

	client.Lifecycles.Add(lifecycle)

	fmt.Println(lifecycle)
	return lifecycle
}
