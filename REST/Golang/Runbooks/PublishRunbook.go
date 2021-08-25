package main

import (
	"encoding/json"
	"log"
	"net/url"

	"net/http"

	"io/ioutil"

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
	runbookName := "MyRunbook"
	snapshotName := "Snapshot XXXXX"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get project
	project, err := client.Projects.GetByName(projectName)

	if err != nil {
		log.Println(err)
	}

	// Get runbook
	runbook := GetRunbook(client, project, runbookName)

	// Get runbook snapshot
	runbookSnapshotId := GetRunbookSnapshot(apiURL, APIKey, space, runbook, snapshotName)

	// Update the runbook
	runbook.PublishedRunbookSnapshotID = runbookSnapshotId
	client.Runbooks.Update(runbook)
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

func GetRunbook(client *octopusdeploy.Client, project *octopusdeploy.Project, runbookName string) *octopusdeploy.Runbook {
	// Get runbook
	runbooks, err := client.Runbooks.GetAll()

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(runbooks); i++ {
		if runbooks[i].ProjectID == project.ID && runbooks[i].Name == runbookName {
			return runbooks[i]
		}
	}

	return nil
}

func GetRunbookSnapshot(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, runbook *octopusdeploy.Runbook, snapshotName string) string {
	snapshotApi := octopusURL.String() + "/api/" + space.ID + "/runbooks/" + runbook.ID + "/runbooksnapshots"

	// Create http client
	httpClient := &http.Client{}

	// Make post request
	request, err := http.NewRequest("GET", snapshotApi, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	request.Header.Set("Content-Type", "application/json")

	// Execute post and get response
	response, err := httpClient.Do(request)

	responseData, err := ioutil.ReadAll(response.Body)

	var f interface{}
	jsonErr := json.Unmarshal(responseData, &f)
	if jsonErr != nil {
		log.Println(err)
	}

	runbookSnapshotMap := f.(map[string]interface{})

	runbookSnapshotItems := runbookSnapshotMap["Items"].([]interface{})

	for _, snapshot := range runbookSnapshotItems {
		entry := snapshot.(map[string]interface{})
		if entry["Name"].(string) == snapshotName {
			return entry["Id"].(string)
		}
	}

	return ""
}