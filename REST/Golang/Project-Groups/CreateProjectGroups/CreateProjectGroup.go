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
	projectID := os.Args[4]

	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	octopusAuth(octopusURL, APIKey, space)
	CreateProjectGroup(octopusURL, APIKey, space, name, projectID)

}

func octopusAuth(octopusURL, APIKey, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateProjectGroup(octopusURL, APIKey, space, name, projectID string) *model.ProjectGroup {
	client := octopusAuth(octopusURL, APIKey, space)
	ProjectGroup := model.NewProjectGroup(name)

	client.ProjectGroups.Add(ProjectGroup)

	return ProjectGroup
}
