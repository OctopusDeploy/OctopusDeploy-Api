#!/bin/bash

# Define working variables
octopusURL="https://youroctourl"
octopusAPIKey="API-YOURAPIKEY"
header="X-Octopus-ApiKey: $octopusAPIKey"
spaceName="default"
machineName="partialMachineName"    # will use continas

# Get space id
spaceId=$(curl -sS -H "$header" "$octopusURL/api/spaces/all" | jq -r ".[] | select(.Name==\"$spaceName\") | .Id")

# Get machine list and find the targets with matching partialname
targetIds=$(curl -sS -H "$header" "$octopusURL/api/$spaceId/machines?partialName=$machineName&skip=0&take=1000" | jq -r ".Items[] | .Id")

if [ -z "$targetIds" ]; then
    echo "No targets found matching partial name '$machineName'"
    exit 0
fi

for targetId in $targetIds; do
    echo "Deleting the target $targetId because the name matches the partial name '$machineName'"
    deleteResponse=$(curl -sS -H "$header" -X DELETE "$octopusURL/api/$spaceId/machines/$targetId")
    echo "Delete Response $deleteResponse"
done