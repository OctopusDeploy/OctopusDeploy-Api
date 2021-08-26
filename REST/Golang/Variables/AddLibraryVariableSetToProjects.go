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
	librarySet := GetLibrarySet(apiURL, APIKey, space, librarySetName, 0)

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
		Name: projectName,
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

func GetLibrarySet(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, librarySetName string, skip int) *octopusdeploy.LibraryVariableSet {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	librarySetsQuery := octopusdeploy.LibraryVariablesQuery {
		PartialName: librarySetName,
	}

	librarySets, err := client.LibraryVariableSets.Get(librarySetsQuery)
	if err != nil {
		log.Println(err)
	}
	
	if len(librarySets.Items) == librarySets.ItemsPerPage {
		// call again
		librarySet := GetLibrarySet(octopusURL, APIKey, space, librarySetName, (skip + len(librarySets.Items)))

		if librarySet != nil {
			return librarySet
		}
	} else {
		// Loop through returned items
		for _, librarySet := range librarySets.Items {
			if librarySet.Name == LifecycleName {
				return librarySet
			}
		}
	}

	return nil
}