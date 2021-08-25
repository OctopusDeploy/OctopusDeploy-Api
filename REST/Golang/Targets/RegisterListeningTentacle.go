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

type DiscoveredMachine struct {
	Architecture      string
	Endpoint          EndPoint
	HasLatestCalamari bool
	HealthStatus      string
	IsDisabled        bool
	IsInProcess       bool
	Name              string
	Status            string
}

type EndPoint struct {
	CertificateSignatureAlgorithm string
	CommunicationStyle            string
	Id                            string
	LastModifiedBy                string
	LastModifiedOn                string
	Thumbprint                    string
	Uri                           string
}

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"

	spaceName := "Default"
	hostName := "MyMachine"
	tentaclePort := 10933
	environments := []string{"Development", "Test"}
	roles := []string{"MyRole"}

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Creat client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get the environment ids
	environmentIds := GetEnvironmentIds(client, environments)

	// The client doesn't have this *yet* so we're hitting the API directly
	discoveredMachine := DiscoverMachine(apiURL, APIKey, hostName, tentaclePort, space)

	// Create new machine
	parsedUri, err := url.Parse(discoveredMachine.Endpoint.Uri)
	if err != nil {
		log.Println(err)
	}

	newDeploymentTargetEndpoint := octopusdeploy.NewListeningTentacleEndpoint(parsedUri, discoveredMachine.Endpoint.Thumbprint)
	newDeploymentTargetEndpoint.Thumbprint = discoveredMachine.Endpoint.Thumbprint

	newDeploymentTarget := octopusdeploy.NewDeploymentTarget(hostName, newDeploymentTargetEndpoint, environmentIds, roles)

	machine, err := client.Machines.Add(newDeploymentTarget)
	if err != nil {
		log.Println(err)
	}

	fmt.Println(machine)
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
func GetEnvironmentIds(client *octopusdeploy.Client, environmentNames []string) []string {
	environmentIds := []string{}

	for _, environmentName := range environmentNames {
		environmentsQuery := octopusdeploy.EnvironmentsQuery {
		    Name: environmentName,		
	    }  
		environments, err := client.Environments.Get(environmentsQuery)
        if err != nil {
            log.Println(err)
        }

        // Loop through results
        for _, environment := range environments.Items {
            if environment.Name == environmentName {
                environmentIds = append(environmentIds, environment.ID)
            }
        }
	}

	return environmentIds
}

func DiscoverMachine(octopusURL *url.URL, APIKey string, hostname string, port int, space *octopusdeploy.Space) DiscoveredMachine {
	// Construct url
	discoverUrl := octopusURL.String() + "/api/" + space.ID + "/machines/discover?host=" + hostname + "&port=" + strconv.Itoa(port)

	// Create http client
	httpClient := &http.Client{}

	// Create request object
	request, err := http.NewRequest("GET", discoverUrl, nil)
	if err != nil {
		log.Println(err)
	}

	request.Header.Set("X-Octopus-ApiKey", APIKey)
	request.Header.Set("Content-Type", "application/json")

	// Execute request
	response, err := httpClient.Do(request)
	if err != nil {
		log.Println(err)
	}

	// Get the response
	var machine DiscoveredMachine

	responseData, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Println(err)
	}

	json.Unmarshal(responseData, &machine)

	return machine
}