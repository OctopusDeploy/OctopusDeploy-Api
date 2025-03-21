#!/usr/bin/env bash

# Define working variables
octopusURL="https://.octopus.app"
octopusAPIKey="API-"
spaceName="SpaceName"
projectName="ProjectName"
releaseVersion="1.0.0.1"
# Optional - Force a package version in the release. Uncomment the code at line 55 and comment out line 60 to use latest.
packageVersion="1.1.5"
branchName=""
channelName="Default"

# Get space
space=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$octopusURL/api/spaces/all" | jq -r ".[] | select(.Name==\"$spaceName\")")
spaceId=$(echo "$space" | jq -r .Id)

# Get project
project=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$octopusURL/api/$spaceId/projects/all" | jq -r ".[] | select(.Name==\"$projectName\")")
projectId=$(echo "$project" | jq -r .Id)

# Get channel
channel=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$octopusURL/api/$spaceId/projects/$projectId/channels" | jq -r ".Items[] | select(.Name==\"$channelName\")")
channelId=$(echo "$channel" | jq -r .Id)

# Initialize release payload
releaseBody="{ \"ChannelId\": \"$channelId\", \"ProjectId\": \"$projectId\", \"Version\": \"$releaseVersion\", \"VersionControlReference\": null, \"SelectedPackages\": [] }"

# Check if project is Config-as-Code
isVersionControlled=$(echo "$project" | jq -r .IsVersionControlled)
if [ "$isVersionControlled" == "true" ]; then
    if [ -z "$branchName" ]; then
        echo "BranchName is not provided. Looking up default branch"
        branchName=$(echo "$project" | jq -r .PersistenceSettings.DefaultBranch)
    fi
    projectBranch=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$octopusURL/api/$spaceId/projects/$projectId/git/branches/$branchName")
    canonicalBranch=$(echo "$projectBranch" | jq -r .CanonicalName)
    templateLink="$octopusURL$(echo "$projectBranch" | jq -r .Links.ReleaseTemplate | sed "s/{\?channel,releaseId}/?channel=$channelId/")"
    releaseBody=$(echo "$releaseBody" | jq ".VersionControlReference = { \"GitRef\": \"$canonicalBranch\" }")
else
    templateLink="$octopusURL/api/$spaceId/deploymentprocesses/deploymentprocess-$projectId/template?channel=$channelId"
fi

# Get deployment process template
template=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$templateLink")

# Loop through the deployment process packages and add to release payload
selectedPackages="[]"
while read -r row; do
    feedId=$(echo "$row" | jq -r .FeedId)
    packageId=$(echo "$row" | jq -r .PackageId)
    actionName=$(echo "$row" | jq -r .ActionName)
    packageReferenceName=$(echo "$row" | jq -r .PackageReferenceName)
    
    # Use latest version of the package in the built-in feed
    # uri="$octopusURL/api/$spaceId/feeds/$feedId/packages/versions?packageId=$packageId&take=1"
    # version=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$uri" | jq -r ".Items[0].Version")

    # Use specified version of the packages. Comment this line out if using the latest code above.
    version=$packageVersion

    # Append package information
    selectedPackages=$(echo "$selectedPackages" | jq ". + [{ \"ActionName\": \"$actionName\", \"PackageReferenceName\": \"$packageReferenceName\", \"Version\": \"$version\" }]")
done < <(echo "$template" | jq -c '.Packages[]')

releaseBody=$(echo "$releaseBody" | jq ".SelectedPackages = $selectedPackages")

# Create the release
release=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" -X POST "$octopusURL/api/$spaceId/releases" -d "$releaseBody" --header "Content-Type: application/json")

# Display created release
echo "$release" | jq
