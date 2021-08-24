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
	libraryVariableSetName := "MyLibraryVariableSet"
	variableName := "MyVariable"
	variableValue := "MyValue"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	fmt.Printf("Looking for library variable set '%[1]s", libraryVariableSetName)

	// Get the library library set
	librarySet := GetLibrarySet(client, space, libraryVariableSetName, 0)

	// Get the variable set
	variableSet, err := client.Variables.GetAll(librarySet.ID)
	if err != nil {
		log.Println(err)
	}

	// Loop through variables
	for _, variable := range variableSet.Variables {
		if variable.Name == variableName {
			variable.Value = variableValue
			break
		}
	}

	// Update the set
	client.Variables.Update(librarySet.ID, variableSet)
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

func GetLibrarySet(client *octopusdeploy.Client, space *octopusdeploy.Space, librarySetName string, skip int) *octopusdeploy.LibraryVariableSet {
	// Create library sets query
	librarySetsQuery := octopusdeploy.LibraryVariablesQuery{
		PartialName: librarySetName,
	}

	// Get Library set
	librarySets, err := client.LibraryVariableSets.Get(librarySetsQuery)

	if err != nil {
		log.Println(err)
	}

	// Loop through results
	if len(librarySets.Items) == librarySets.ItemsPerPage {
		// Call again
		librarySet := GetLibrarySet(client, space, librarySetName, (skip + len(librarySets.Items)))

		if librarySet != nil {
			return librarySet
		}
	} else {
		for _, librarySet := range librarySets.Items {
			if librarySet.Name == librarySetName {
				return librarySet
			}
		}
	}

	return nil
}