package main

import (
	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
)

var (
	// Declare working variables
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"

	spaceName                   string = "Default"
	feedName                    string = "nuget.org 3"
	feedURI                     string = "https://api.nuget.org/v3/index.json"
	downloadAttempts            int    = 5
	downloadRetryBackoffSeconds int    = 10
	useExtendedAPI              bool   = false
	// optional
	feedUsername string = ""
	feedPassword string = ""
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		// TODO: handle error
	}

	feedResource := model.NewNuGetFeed(feedName)

	if err != nil {
		// TODO: handle error
	}

	feedResource.SpaceID = space.ID
	feedResource.FeedURI = feedURI
	feedResource.DownloadAttempts = downloadAttempts
	feedResource.DownloadRetryBackoffSeconds = downloadRetryBackoffSeconds
	feedResource.EnhancedMode = useExtendedAPI

	if len(feedUsername) > 0 {
		feedResource.Username = feedUsername
	}

	if len(feedPassword) > 0 {
		feedResource.Password = model.NewSensitiveValue(feedPassword)
	}

	feed, err := client.Feeds.Add(*feedResource)

	if err != nil {
		// TODO: handle error
	}
}
