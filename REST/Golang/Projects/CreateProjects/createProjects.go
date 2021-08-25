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
	projectName := "MyProject"
	projectGroupName := "MyProjectGroup"
	lifeCycleName := "Default Lifecycle"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get project group
	projectGroup := GetProjectGroup(client, projectGroupName)

	// Get lifecycle
	lifecycle := GetLifecycle(client, lifeCycleName)

	// Create project
	project := CreateProject(client, lifecycle, projectGroup, projectName)

	fmt.Println("Created project " + project.ID)
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

func GetProjectGroup(client *octopusdeploy.Client, projectGroupName string) *octopusdeploy.ProjectGroup {
	// Get matching project groups
	projectGroups, err := client.ProjectGroups.GetByPartialName(projectGroupName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(projectGroups); i++ {
		if projectGroups[i].Name == projectGroupName {
			return projectGroups[i]
		}
	}

	return nil
}

func GetLifecycle(client *octopusdeploy.Client, lifecycleName string) *octopusdeploy.Lifecycle {
	// Get lifecycle
	lifecycles, err := client.Lifecycles.GetByPartialName(lifecycleName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(lifecycles); i++ {
		if lifecycles[i].Name == lifecycleName {
			return lifecycles[i]
		}
	}

	return nil
}

func CreateProject(client *octopusdeploy.Client, lifecycle *octopusdeploy.Lifecycle, projectGroup *octopusdeploy.ProjectGroup, name string) *octopusdeploy.Project {
	project := octopusdeploy.NewProject(name, lifecycle.ID, projectGroup.ID)

	project, err := client.Projects.Add(project)

	if err != nil {
		log.Println(err)
	}

	return project
}