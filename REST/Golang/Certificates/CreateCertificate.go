package main

import (
	"fmt"
	"log"
	"net/url"

	b64 "encoding/base64"
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
	certificateName := "MyCertificate"
	pathToCertificate := "path:\\To\\PFXFile.pfx"
	pfxPassword := "YourPassword"
	rawData, err := ioutil.ReadFile(pathToCertificate)

	if err != nil {
		log.Println(err)
	}

    // Convert byte array to base 64 string
	stringRawData := b64.StdEncoding.EncodeToString([]byte(rawData))

    // Create new certificate sensitive value
    certificateData := octopusdeploy.SensitiveValue{
		HasValue: true,
		NewValue: &stringRawData,
	}

    // Create PFX Password as sensitive value
	sensitivePfxPassword := octopusdeploy.SensitiveValue{
		HasValue: true,
		NewValue: &pfxPassword,
	}

	// Create new certificate resource
	certificate := octopusdeploy.NewCertificateResource(certificateName, &certificateData, &sensitivePfxPassword)

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Create certificate
	certificate, err = client.Certificates.Add(certificate)

	if err != nil {
		log.Println(err)
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