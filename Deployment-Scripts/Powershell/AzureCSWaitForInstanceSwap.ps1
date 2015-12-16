# Loop until all instances are running
do {
    $ready=0
    $total=0

    # query the status of the running instances
    $list = (Get-AzureRole -ServiceName #{YourCloudService} -Slot Staging -InstanceDetails).InstanceStatus 

    # count the number of ready instances
    $list | foreach-object { IF ($_ -eq "ReadyRole") { $ready++ } }

    # count the number in total
    $list | foreach-object { $total++ } 

    Write-Host "$ready out of $total instances are ready"

    # Sleep for 10 seconds
    Start-Sleep -s 10
}
while ($ready -ne $total)

# Swap staging and production
Move-AzureDeployment -ServiceName #{YourCloudService} 

# Remove the staging slot
Remove-AzureDeployment -ServiceName #{YourCloudService} -Slot Staging -Force
