# Run on *each* Linux Polling Tentacle VM

# ** Note: There will be down time in comms with your Polling Tentacles until after you have completed running this script on *each* VM where a Polling Tentacle is installed. **

# Trust new Octopus Server thumbprint
echo "Trust the new Octopus Server certificate / thumbprint..."
sudo ./Tentacle update-trust --oldThumbprint "1111111111111111111111111111111111111111" --newThumbprint "1234567890123456789012345678901234567890"
echo "Successfully completed trusting the Octopus Server certificate / thumbprint."
