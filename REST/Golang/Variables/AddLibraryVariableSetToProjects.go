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
	librarySetName := "MyLibrarySet"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get referece to project
	project := GetProject(apiURL, APIKey, space, projectName)

	// Get referece to libraryset
	librarySet := GetLibrarySet(apiURL, APIKey, space, librarySetName)

	// Add set to project
	if project != nil {
		if librarySet != nil {
			// Create client
			client := octopusAuth(apiURL, APIKey, space.ID)

			project.IncludedLibraryVariableSets = append(project.IncludedLibraryVariableSets, librarySet.ID)

			client.Projects.Update(project)
		} 
	}
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
		Name: projectName
	}

	projects, err := client.Projects.Get(projectsQuery)
	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved project " + project.Name)
	}

	for _, project := range projects {
		if project.Name == projectName {
			return project
		}
	}

	return nil
}

func GetLibrarySet(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, librarySetName string) *octopusdeploy.LibraryVariableSet {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get Library set
	librarySets, err := client.LibraryVariableSets.GetByPartialName(librarySetName)

	if err != nil {
		log.Println(err)
	}

	// Loop through results
	for i := 0; i < len(librarySets); i++ {
		if librarySets[i].Name == librarySetName {
			return librarySets[i]
		}
	}

	return nil
}