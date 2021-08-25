package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
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
	filePath := "path:\\to\\package.X.X.X.X.zip"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)
	url := apiURL.String() + "/api/" + space.ID + "/packages/raw?replace=false"

	UploadPackage(filePath, url, APIKey)
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

func UploadPackage(filePath string, url string, APIKey string) {

	file, err := os.Open(filePath)
	if err != nil {
		log.Println(err)
	}

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("filedata", filepath.Base(file.Name()))
	if err != nil {
		log.Println(err)
	}

	io.Copy(part, file)

	writer.Close()

	request, err := http.NewRequest("POST", url, body)
	if err != nil {
		log.Println(err)
	}

	fileStats, err := file.Stat()
	if err != nil {
		log.Println(err)
	}

	fileSize := strconv.FormatInt(fileStats.Size(), 10)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	request.Header.Set("Upload-Offset", "0")
	request.Header.Set("Content-Length", fileSize)
	request.Header.Set("Upload-Length", fileSize)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	client := &http.Client{}

	response, err := client.Do(request)
	if err != nil {
		log.Println(err)
	}

	defer response.Body.Close()
}