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
	projectGroup := GetProjectGroup(client, projectGroupName, 0)

	// Get lifecycle
	lifecycle := GetLifecycle(apiURL, APIKey, space, lifeCycleName, 0)

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

func GetProjectGroup(client *octopusdeploy.Client, projectGroupName string, skip int) *octopusdeploy.ProjectGroup {
    projectGroupsQuery := octopusdeploy.ProjectGroupsQuery {
		PartialName: projectGroupName,
	}

	projectGroups, err := client.ProjectGroups.Get(projectGroupsQuery)

	if err != nil {
		log.Println(err)
	}
	
	if len(projectGroups.Items) == projectGroups.ItemsPerPage {
		// call again
		projectGroup := GetProjectGroup(client, projectGroupName, (skip + len(projectGroups.Items)))

		if projectGroup != nil {
			return projectGroup
		}
	} else {
		// Loop through returned items
		for _, projectGroup := range projectGroups.Items {
			if projectGroup.Name == projectGroupName {
				return projectGroup
			}
		}
	}

	return nil
}

func GetLifecycle(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, LifecycleName string, skip int) *octopusdeploy.Lifecycle {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	lifecycleQuery := octopusdeploy.LifecyclesQuery {
		PartialName: LifecycleName,
	}

	lifecycles, err := client.Lifecycles.Get(lifecycleQuery)

	if err != nil {
		log.Println(err)
	}
	
	if len(lifecycles.Items) == lifecycles.ItemsPerPage {
		// call again
		lifecycle := GetLifecycle(octopusURL, APIKey, space, LifecycleName, (skip + len(lifecycles.Items)))

		if lifecycle != nil {
			return lifecycle
		}
	} else {
		// Loop through returned items
		for _, lifecycle := range lifecycles.Items {
			if lifecycle.Name == LifecycleName {
				return lifecycle
			}
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