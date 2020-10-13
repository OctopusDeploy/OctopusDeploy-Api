package main

import (
	"fmt"
	"log"

	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	hashpass()
}

func hashpass() {
	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)
}
