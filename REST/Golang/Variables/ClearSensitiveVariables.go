package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("http://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "MySace"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get reference to all projects
	projects := GetProjects(apiURL, APIKey, space)

	// Loop through projects
	for i := 0; i < len(projects); i++ {
		//projectVariables := GetProjectVariables(apiURL, APIKey, projects[i])
		projectVariables := GetVariables(apiURL, APIKey, space, projects[i].ID)
		variablesUpdated := false
		for j := 0; j < len(projectVariables.Variables); j++ {
			if projectVariables.Variables[j].IsSensitive {
				projectVariables.Variables[j].Value = ""
				variablesUpdated = true
			}
		}

		if variablesUpdated {
			println("Variables for " + projects[i].Name + " have been updated")
			UpdateVariables(apiURL, APIKey, space, projectVariables.OwnerID, projectVariables)
		}
	}

	// Get reference to library variable sets
	librarySets := GetLibraryVariableSets(apiURL, APIKey, space)

	// Loop through sets
	for i := 0; i < len(librarySets); i++ {
		librarysetVariables := GetVariables(apiURL, APIKey, space, librarySets[i].ID)
		variablesUpdated := false
		for j := 0; j < len(librarysetVariables.Variables); j++ {
			if librarysetVariables.Variables[j].IsSensitive {
				librarysetVariables.Variables[j].Value = ""
				variablesUpdated = true
			}
		}

		if variablesUpdated {
			println("Variables for " + librarySets[i].Name + " have been updated")
			UpdateVariables(apiURL, APIKey, space, librarysetVariables.OwnerID, librarysetVariables)
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

func GetProjects(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space) []*octopusdeploy.Project {
	// Create client object
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get all projects
	projects, err := client.Projects.GetAll()

	if err != nil {
		log.Println(err)
	}

	return projects
}

func GetVariables(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, ownerID string) octopusdeploy.VariableSet {
	// Create client object
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// retrieve variables
	variables, err := client.Variables.GetAll(ownerID)

	if err != nil {
		log.Println(err)
	}

	return variables
}

func GetLibraryVariableSets(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space) []*octopusdeploy.LibraryVariableSet {
	// Create client object
	client := octopusAuth(octopusURL, APIKey, space.ID)

	librarySets, err := client.LibraryVariableSets.GetAll()

	if err != nil {
		log.Println(err)
	}

	return librarySets
}

func UpdateVariables(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, ownerID string, variables octopusdeploy.VariableSet) {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	variableSet, err := client.Variables.Update(ownerID, variables)

	if err != nil {
		log.Println(err)
	}

	fmt.Println(variableSet.ID + " updated")
}