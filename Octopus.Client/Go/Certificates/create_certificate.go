package main

import (
	"encoding/base64"
	"io/ioutil"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

var (
	// Declare working variables
	octopusURL      string = "https://youroctourl"
	octopusAPIKey   string = "API-YOURAPIKEY"
	pfxFilePath     string = "path\\to\\pfxfile.pfx"
	pfxFilePassword string = "PFX-file-password"
	certificateName string = "MyCertificate"
	spaceName       string = "default"
)

func main() {
	client, err := octopusdeploy.NewClient(nil, octopusURL, octopusAPIKey, spaceName)
	if err != nil {
		// TODO: handle error
	}

	file, err := os.Open(pfxFilePath)
	if err != nil {
		// TODO: handle error
	}

	data, err := ioutil.ReadAll(file)
	if err != nil {
		// TODO: handle error
	}

	// Convert file to base64
	base64Certificate := base64.StdEncoding.EncodeToString(data)

	// Create certificate object
	certificateData := octopusdeploy.NewSensitiveValue(base64Certificate)
	password := octopusdeploy.NewSensitiveValue(pfxFilePassword)
	octopusCertificate := octopusdeploy.NewCertificate(certificateName, certificateData, password)

	client.Certificates.Add(octopusCertificate)
}
