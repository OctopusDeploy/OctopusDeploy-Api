package main

import (
	"encoding/json"
	"fmt"
	"log"

	"net/http"
	"net/url"

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
	channelName := "Default"
	environmentName := "Development"
	projectName := "MyProject"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get project
	project := GetProject(client, projectName)

	// Get channel
	channel := GetChannel(client, project, channelName)

	// Get template
	template := GetDeploymentProcessTemplate(apiURL, APIKey, space, project, channel)

	// Get environment
	environment := GetEnvironment(client, environmentName)

    releaseVersion := ""

	// Check to see if the nexversionincrement property is nil
	if nil == template["NextVersionIncrement"] {
		// Project uses a package instead of a template, get the latest version of the package
		deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)

		if err != nil {
			log.Println(err)
		}

		versionNumberFound := false

		for i := 0; i < len(deploymentProcess.Steps); i++ {
			if deploymentProcess.Steps[i].Name == template["VersioningPackageStepName"].(string) {
				for j := 0; j < len(deploymentProcess.Steps[i].Actions); j++ {
					releasePackage := deploymentProcess.Steps[i].Actions[j].Packages[0]
					releaseVersion = GetPackageVersion(apiURL, APIKey, space, releasePackage.FeedID, releasePackage.PackageID)
					versionNumberFound = true
					break
				}
			}
			if versionNumberFound {
				break
			}
		}

	} else {
		releaseVersion = template["NextVersionIncrement"].(string)
	}

	// Create new release object
	release := octopusdeploy.NewRelease(channel.ID, project.ID, releaseVersion)

	// Get packages for release
	packages := template["Packages"].([]interface{})
	for i := 0; i < len(packages); i++ {
		// Get selected package map
		packageMap := packages[i].(map[string]interface{})

		version := GetPackageVersion(apiURL, APIKey, space, packageMap["FeedId"].(string), packageMap["PackageId"].(string))

		// create selected package object
		selectedPackage := octopusdeploy.SelectedPackage{
			ActionName:           packageMap["ActionName"].(string),
			PackageReferenceName: packageMap["PackageReferenceName"].(string),
			Version:              version,
		}

		// add selected package
		release.SelectedPackages = append(release.SelectedPackages, &selectedPackage)
	}

	// Create release
	release, err = client.Releases.Add(release)

	if err != nil {
		log.Println(err)
	}

	fmt.Println("Created release version: " + release.Version)
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

func GetEnvironment(client *octopusdeploy.Client, EnvironmentName string) *octopusdeploy.Environment {
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

func GetChannel(client *octopusdeploy.Client, project *octopusdeploy.Project, ChannelName string) *octopusdeploy.Channel {
	channelQuery := octopusdeploy.ChannelsQuery{
		PartialName: ChannelName,
		Skip:        0,
	}

	results := []*octopusdeploy.Channel{}

	for true {
		// Call for results
		channels, err := client.Channels.Get(channelQuery)

		if err != nil {
			log.Println(err)
		}

		// Check returned number of items
		if len(channels.Items) == 0 {
			break
		}

		// append items to results
		results = append(results, channels.Items...)

		// Update query
		channelQuery.Skip += len(channels.Items)
	}

	for i := 0; i < len(results); i++ {
		if results[i].ProjectID == project.ID && results[i].Name == ChannelName {
			return results[i]
		}
	}

	return nil
}

func GetDeploymentProcessTemplate(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, project *octopusdeploy.Project, channel *octopusdeploy.Channel) map[string]interface{} {
	// Query api for tasks
	templateApi := octopusURL.String() + "/api/" + space.ID + "/deploymentprocesses/deploymentprocess-" + project.ID + "/template?channel=" + channel.ID

	// Create http client
	httpClient := &http.Client{}

	// perform request
	request, _ := http.NewRequest("GET", templateApi, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)

	if err != nil {
		log.Println(err)
	}

	responseData, err := ioutil.ReadAll(response.Body)

	var f interface{}
	jsonErr := json.Unmarshal(responseData, &f)
	if jsonErr != nil {
		log.Println(err)
	}

	template := f.(map[string]interface{})

	// return the template
	return template
}

func GetPackageVersion(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, feedId string, packageId string) string {
	packageApi := octopusURL.String() + "/api/" + space.ID + "/feeds/" + feedId + "/packages/versions?packageId=" + packageId

	// Create http client
	httpClient := &http.Client{}

	// perform request
	request, _ := http.NewRequest("GET", packageApi, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)

	if err != nil {
		log.Println(err)
	}

	responseData, err := ioutil.ReadAll(response.Body)

	var f interface{}
	jsonErr := json.Unmarshal(responseData, &f)
	if jsonErr != nil {
		log.Println(err)
	}

	// Map the returned data
	packageItems := f.(map[string]interface{})

	// Returns the list of items, translate it to a map
	returnedItems := packageItems["Items"].([]interface{})

	// We only need the most recent version
	mostRecentPackageVersion := returnedItems[0].(map[string]interface{})

	return mostRecentPackageVersion["Version"].(string)
}