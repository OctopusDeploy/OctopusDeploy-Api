# Run on *each* Linux Listening Tentacle VM

# Trust new Octopus Server thumbprint
echo "Trust the new Octopus Server certificate / thumbprint..."
sudo ./Tentacle configure --trust="<new-octopus-server-thumbprint>"
echo "Successfully completed trusting the Octopus Server certificate / thumbprint."

echo "Don't forget, you'll need to come back later and run the script to *stop* trusting the old Octopus Server certificate & thumbprint..."
