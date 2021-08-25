package main

import (
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
	APIKey := "API-YourAPIEKey"

	spaceName := "Default"
	certificateName := "MyCertificate"
	certificateFilePath := "path:\\to\\NewCertificate.pfx"
	certificatePassword := "MyPassword"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Creat client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	rawData, err := ioutil.ReadFile(certificateFilePath)
	if err != nil {
		log.Println(err)
	}

	// Convert data to base64 encoded string
	base64String := b64.StdEncoding.EncodeToString([]byte(rawData))

	// Get certificate
	certificate := GetCertificate(client, certificateName)

	// Replace existing certificate
	replacementCertificate := octopusdeploy.NewReplacementCertificate(base64String, certificatePassword)
	client.Certificates.Replace(certificate.ID, replacementCertificate)
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

func GetCertificate(client *octopusdeploy.Client, certificateName string) *octopusdeploy.CertificateResource {
	certificateQuery := octopusdeploy.CertificatesQuery{
		PartialName: certificateName,
		Archived:    "",
		Skip:        0,
		Take:        1000,
	}

	certificates, err := client.Certificates.Get(certificateQuery)
	if err != nil {
		log.Println(err)
	}

	for _, certificate := range certificates.Items {
		if certificate.Name == certificateName && certificate.Archived == "" {
			return certificate
		}
	}

	return nil
}