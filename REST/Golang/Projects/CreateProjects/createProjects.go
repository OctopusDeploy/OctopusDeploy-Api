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
	projectGroupID := os.Args[4]
	lifecycleID := os.Args[5]

	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	octopusAuth(octopusURL, APIKey, space)
	CreateProject(octopusURL, APIKey, space, name, lifecycleID, projectGroupID)

}

func octopusAuth(octopusURL, APIKey, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateProject(octopusURL, APIKey, space, name, lifecycleID, projectGroupID string) *model.Project {
	client := octopusAuth(octopusURL, APIKey, space)
	Project := model.NewProject(name, lifecycleID, projectGroupID)

	client.Projects.Add(Project)

	return Project
}
