serverUrl="http://octopus.url"
apiKey="API-xxxxxxxxxxxxxxxxxxxxxxxxxx"
header="X-Octopus-ApiKey: $apiKey"

localIp=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}') # or change this to a hardcoded IP
echo SSH Target IP Address: \"$localIp\"
fingerprint=$(ssh-keygen -E md5 -lf /etc/ssh/ssh_host_rsa_key.pub | cut -d' ' -f2 | cut -d: -f2- | awk '{ print $1}') # or change this to a hardcoded SSH Key fingerprint
echo SSH Key fingerprint: \"$fingerprint\"

environmentName="TheEnvironment"
accountName="TheAccount"
machineName="MySshTargetName"

environmentId=$(wget -nv --header="$header" -O- ${serverUrl}/api/environments/all | jq ".[] | select(.Name==\"${environmentName}\") | .Id" -r)
echo Environment \"$environmentName\" '('$environmentId')'

accountId=$(wget -nv --header="$header" -O- ${serverUrl}/api/accounts/all | jq ".[] | select(.Name==\"${accountName}\") | .Id" -r)
echo Account \"$accountName\" '('$accountId')'

# if 'mono' is installed
machineJson="{\"Endpoint\": {\"CommunicationStyle\":\"Ssh\",\"AccountId\":\"$accountId\",\"Host\":\"$localIp\",\"Port\":\"22\",\"Fingerprint\":\"$fingerprint\"},\"EnvironmentIds\":[\"$environmentId\"],\"Name\":\"$machineName\",\"Roles\":[\"linux\"]}"
# if 'mono' is not installed or you want to use the .NET Core version of Calamari.
#dotNetCorePlatform="linux-x64" # Valid values are 'linux-x64' or 'osx-x64'.
#machineJson="{\"Endpoint\": {\"CommunicationStyle\":\"Ssh\",\"AccountId\":\"$accountId\",\"Host\":\"$localIp\",\"Port\":\"22\",\"Fingerprint\":\"$fingerprint\",\"DotNetCorePlatform\":\"$dotNetCorePlatform\"},\"EnvironmentIds\":[\"$environmentId\"],\"Name\":\"$machineName\",\"Roles\":[\"linux\"]}"
machineId=$(wget -nv --header="$header" --post-data "$machineJson" -O- ${serverUrl}/api/machines | jq ".Id" -r)
if [ -n "$machineId" ]
then
    echo Added machine \"$machineName\" '('$machineId')'
    serverTaskId=$(wget -nv --header="$header" --post-data "{\"Name\":\"Health\",\"Description\":\"Check $machineName health\",\"Arguments\":{\"Timeout\":\"00:05:00\",\"MachineIds\":[\"$machineId\"]}}" -O-  ${serverUrl}/api/tasks | jq ".Id" -r)
    echo Health check task created: ${serverUrl}/app#/tasks/${serverTaskId}
fi