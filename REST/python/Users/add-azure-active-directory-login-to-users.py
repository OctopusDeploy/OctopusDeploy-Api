import json
import requests
import csv

# Define class
class userToUpdate:
    OctopusUsername = ''
    AzureEmailAddress = ''
    AzureDisplayName = ''

# Define Octopus server variables
octopus_server_uri = 'https://YourUrl'
octopus_api_key = 'API-YourAPIKey'


# Create function
def AddAzureLogins(OctopusUrl, 
OctopusAPIKey, Path='', 
OctopusUsername='', 
AzureEmailAddress='', 
AzureDisplayName='',
UpdateOctopusEmailAddress=False, 
UpdateOctopusDisplayName=False, 
Force=False, 
WhatIf=False):
    # Display values passed into function
    print ("OctopusURL: ", OctopusUrl)
    print ("OctopusAPIKey: ", "*******")
    print ("Path: ", Path)
    print ("OctopusUsername: ", OctopusUsername)
    print ("AzureEmailAddress: ", AzureEmailAddress)
    print ("AzureDisplayName: ", AzureDisplayName)
    print ("UpdateOctopusEmailAddress", UpdateOctopusEmailAddress)
    print ("UpdateOctopusDisplayName: ", UpdateOctopusDisplayName)  

    headers = {'X-Octopus-ApiKey': OctopusAPIKey}
    usersToUpdate = []

    if Path:
        # Write something to do extraction
        with open(Path) as csvfile:
            csv_reader = csv.reader(csvfile, delimiter=',')
            for row in csv_reader:
                updateUser = userToUpdate()
                updateUser.AzureDisplayName = row[0]
                updateUser.AzureEmailAddress = row[1]
                updateUser.OctopusUsername = row[3]

                usersToUpdate.append(updateUser)
    else:
        updateUser = userToUpdate()
        updateUser.AzureDisplayName = AzureDisplayName
        updateUser.AzureEmailAddress = AzureEmailAddress
        updateUser.OctopusUsername = OctopusUsername

        usersToUpdate.append(updateUser)

    # Gather users from instance
    existingUsers = []
    uri = '{0}/users'.format(OctopusUrl)
    response = requests.get(uri, headers=headers)
    response.raise_for_status()

    # Decode content
    results = json.loads(response.content.decode('utf-8'))
    existingUsers += results["Items"]

    # Loop through remaining results
    while ("Page.Next" in results["Links"]):
            response = requests.get(uri, headers=headers)
            response.raise_for_status()

            # Decode content
            results = json.loads(response.content.decode('utf-8'))
            existingUsers += results["Items"]
    for user in usersToUpdate:
        # Search for user
        existingUser = next((u for u in existingUsers if u["Username"] == user.OctopusUsername), None)
        
        if (existingUser != None):
            print(existingUser)
            # Check to see if user is a service account
            if (existingUser["IsService"] == True):
                print (f"User {user.OctopusUsername} is a service account, skipping ...")
                continue

            if (existingUser["IsActive"] == False):
                print (f"User {user.OctopusUsername} is inactive, skipping...")
                continue

            if (existingUser["Identities"] != None):
                azureAdIdentity = next((u for u in existingUser["Identities"] if u["IdentityProviderName"] == "Azure AD"), None)
                
                if (azureAdIdentity != None):
                    print (f"Found existing Azure AD identity for {user.OctopusUsername} ...")
                    
                    if(Force):
                        print("Force is set to true, overwriting values")
                        azureAdIdentity["Claims"]["email"]["Value"] = user.AzureEmailAddress
                        azureAdIdentity["Claims"]["dn"]["Value"] = user.AzureDisplayName
                    else:
                        print("Force is set to false, skipping...")
                        continue
                else:
                    # Create new Identity
                    newIdentity = {
                        'IdentityProviderName': 'Azure AD',
                        'Claims': {
                            'email': {
                                'Value': user.AzureEmailAddress,
                                'IsIdentifyingClaim': True
                            },
                            'dn':{
                                'Value': user.AzureDisplayName,
                                'IsIdentifyingClaim': False
                            }
                        }
                    }
                    existingUser["Identities"].append(newIdentity)

            if (UpdateOctopusEmailAddress):
                existingUser["EmailAddress"] = user.AzureEmailAddress

            if (UpdateOctopusDisplayName):
                existingUser["DisplayName"] = user.AzureDisplayName

            # Update the user account
            uri = '{0}/users/{1}'.format(OctopusUrl, existingUser['Id'])
            response = requests.put(uri, headers=headers, json=existingUser)
            response.raise_for_status()
    return


AddAzureLogins(octopus_server_uri, octopus_api_key, OctopusUsername='some.email@microsoft.com', AzureDisplayName='DisplayName', AzureEmailAddress='some.email@microsoft.com', Force=True )