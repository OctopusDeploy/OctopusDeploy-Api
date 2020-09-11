package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	URL := os.Args[1]
	apiKey := os.Args[2]

	createProject(URL, apiKey)
}

func createProject(URL string, apiKey string) {

	body, _ := json.Marshal(map[string]string{
		"Name": "testGoCode",
	})

	put, err := http.NewRequest("POST", URL+"/api/projectgroups", bytes.NewBuffer(body))

	if err != nil {
		log.Println(err)
	}

	put.Header.Set("X-Octopus-ApiKey", apiKey)

	client := &http.Client{}
	resp, err := client.Do(put)

	if err != nil {
		panic(err)
	}

	fmt.Println("Response Status:", resp.Status)
}
