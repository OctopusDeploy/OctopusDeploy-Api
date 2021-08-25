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
	tenantName := "MyTenant"
	environmentNames := []string{"Development", "Test"}
	projectNames := []string{"MyProject"}
	tenantTags := []string{"TagSet/Tag"}
	projectEnvironments := make(map[string][]string)

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Loop through environments
	for i := 0; i < len(projectNames); i++ {
		project := GetProject(apiURL, APIKey, space, projectNames[i])
		environmentIds := []string{}
		for j := 0; j < len(environmentNames); j++ {
			environment := GetEnvironment(apiURL, APIKey, space, environmentNames[j])
			environmentIds = append(environmentIds, environment.ID)
		}
		projectEnvironments[project.ID] = environmentIds
	}

	// Create new tenant
	tenant := octopusdeploy.NewTenant(tenantName)
	tenant.SpaceID = space.ID
	tenant.ProjectEnvironments = projectEnvironments
	tenant.TenantTags = tenantTags

	client := octopusAuth(apiURL, APIKey, space.ID)
	client.Tenants.Add(tenant)
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

func GetProject(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, projectName string) *octopusdeploy.Project {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	projectsQuery := octopusdeploy.ProjectsQuery {
		Name: projectName,
	}

	// Get specific project object
	projects, err := client.Projects.Get(projectsQuery)

	if err != nil {
		log.Println(err)
	}

	for _, project := range projects.Items {
		if project.Name == projectName {
			return project
		}
	}

	return nil
}

func GetEnvironment(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, EnvironmentName string) *octopusdeploy.Environment {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	environments, err := client.Environments.GetByName(EnvironmentName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(environments); i++ {
		if environments[i].Name == EnvironmentName {
			return environments[i]
		}
	}

	return nil
}