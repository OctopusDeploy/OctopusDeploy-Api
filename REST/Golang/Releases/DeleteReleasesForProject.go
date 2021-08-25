package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strconv"

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

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get project
	project := GetProject(client, projectName)

	// Get project releases
	projectReleases := GetProjectReleases(apiURL, APIKey, space, project)

	// Loop through releases
	for i := 0; i < len(projectReleases); i++ {
		projectRelease := projectReleases[i].(map[string]interface{})

		// Delete release
		fmt.Println("Deleting " + projectRelease["Id"].(string))
		client.Releases.DeleteByID(projectRelease["Id"].(string))
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

func GetProject(client *octopusdeploy.Client, projectName string) *octopusdeploy.Project {
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

func GetProjectReleases(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, project *octopusdeploy.Project) []interface{} {
	// Define api endpoint
	projectReleasesEndoint := octopusURL.String() + "/api/" + space.ID + "/projects/" + project.ID + "/releases"

	// Create http client
	httpClient := &http.Client{}
	skipAmount := 0

	// Make request
	request, _ := http.NewRequest("GET", projectReleasesEndoint, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)

	if err != nil {
		log.Println(err)
	}

	// Get response
	responseData, err := ioutil.ReadAll(response.Body)
	var releasesJson interface{}
	err = json.Unmarshal(responseData, &releasesJson)

	// Map the returned data
	returnedReleases := releasesJson.(map[string]interface{})
	// Returns the list of items, translate it to a map
	returnedItems := returnedReleases["Items"].([]interface{})

	//make(map[string][]octopusdeploy.PropertyValue)

	for true {
		// check to see if there's more to get
		fltItemsPerPage := returnedReleases["ItemsPerPage"].(float64)
		itemsPerPage := int(fltItemsPerPage)

		if len(returnedReleases["Items"].([]interface{})) == itemsPerPage {
			// Increment skip accoumt
			skipAmount += len(returnedReleases["Items"].([]interface{}))

			// Make request
			queryString := request.URL.Query()
			queryString.Set("skip", strconv.Itoa(skipAmount))
			request.URL.RawQuery = queryString.Encode()
			response, err := httpClient.Do(request)

			if err != nil {
				log.Println(err)
			}

			responseData, err := ioutil.ReadAll(response.Body)
			var releasesJson interface{}
			err = json.Unmarshal(responseData, &releasesJson)

			returnedReleases = releasesJson.(map[string]interface{})
			returnedItems = append(returnedItems, returnedReleases["Items"].([]interface{})...)
		} else {
			break
		}
	}

	return returnedItems
}