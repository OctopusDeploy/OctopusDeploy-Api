package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func main() {
	url := os.Args[1]
	apiKey := os.Args[2]

	response, err := http.NewRequest("GET", url+"/api/projects", nil)
	response.Header.Add("X-Octopus-ApiKey", apiKey)

	if err != nil {
		log.Println(err)
	}

	client := &http.Client{}
	resp, _ := client.Do(response)

	output, _ := ioutil.ReadAll(resp.Body)
	fmt.Println(string(output))
}
