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

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
}

func GetProject(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, projectName string) *octopusdeploy.Project {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get project
	project, err := client.Projects.GetByName(projectName)

	if err != nil {
		log.Println(err)
	}

	if project != nil {
		fmt.Println("Retrieved project " + project.Name)
	} else {
		fmt.Println("Project " + projectName + " not found!")
	}

	return project
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