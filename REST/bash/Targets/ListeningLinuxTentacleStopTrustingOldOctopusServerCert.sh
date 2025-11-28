# Run on *each* Linux Listening Tentacle VM

# Stop trusting the old certificate
echo "Stop trusting the old Octopus Server certificate..."
sudo ./Tentacle configure --instance Tentacle --remove-trust <old-thumbprint>
echo "Successfully completed removing the old Octopus Server certificate"

# Restart the Tentacle service
echo "Restarting the Tentacle service..."
sudo ./Tentacle service --instance Tentacle --restart
echo "Successfully completed restarting the Tentacle service"
