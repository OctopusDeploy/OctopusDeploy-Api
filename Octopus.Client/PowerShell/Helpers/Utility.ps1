class utility {
    utility () {
        $this.start_up();
    }

    # Assign these accrordingly...
    static [string] $octodeployUri = '';
    static [string] $domainControllerName = '';

    static [string] $tfsPersonalAccessTokenKey = "TFS_PAT_KEY";
    static [string] $octodeployApiKey = "OCTODEPLOY_API_KEY";
    static [string] $workingDirectory = "C:\Temp\Powershell\";
    static [string] $referenceLibraryPath =  '.\ReferenceLibrary\';
    static [string] $nugetSource = 'https://www.nuget.org/api/v2/';
    static [string] $octopusClientDllVersion = "4.33.1";
    static [string] $octopusClientDllPath = [utility]::referenceLibraryPath + "Octopus.Client." + [utility]::octopusClientDllVersion + "\lib\net45\Octopus.Client.dll";
   
    [void] start_up () {
        $this.verify_octoclient_package();
        $this.verify_octoposh_module();
        $this.get_octodeploy_api_key();
        $this.set_octoposh_connection_info();
        $this.cie_working_directory();
    }

    [string] get_octodeploy_api_key () {
        [string]$octoApiKey = [utility]::octodeployApiKey;
        $environmentVariableTarget = "User";
        $octodeployApiKeyValue = [Environment]::GetEnvironmentVariable($octoApiKey, $environmentVariableTarget);

        if (-not($octodeployApiKeyValue)) {
            Write-Warning "API Key is required.  See APIKey_Create.ps1 for help.";
            $apiKey = Read-Host 'What is your api key?';

            if ($apiKey) {
                [Environment]::SetEnvironmentVariable($octoApiKey, $apiKey, $environmentVariableTarget);
                $octodeployApiKeyValue = [Environment]::GetEnvironmentVariable($octoApiKey, $environmentVariableTarget);
            }
        }

        if (-not($octodeployApiKeyValue)) {
            Write-Warning "Unable to get $octoApiKey value";
            throw "Unable to get $octoApiKey value.";
        }
        else {
            return $octodeployApiKeyValue;
        }
    }

    [System.Object] get_octopus_server_endpoint () {
        $uri = [utility]::octodeployUri;
        $apiKey = $this.get_octodeploy_api_key();

        return New-Object Octopus.Client.OctopusServerEndpoint $uri, $apiKey;
    }

    [System.Object] get_octopus_repository () {
        $endpoint = $this.get_octopus_server_endpoint();

        return New-Object Octopus.Client.OctopusRepository $endpoint;
    }

    [void] set_octoposh_connection_info () {
        $uri = [utility]::octodeployUri;
        Set-OctopusConnectionInfo -URL $uri -APIKey $this.get_octodeploy_api_key();
    }

    [void] verify_octoclient_package () {
        $octoClientDLLPath = [utility]::octopusClientDllPath;
        $destination = [utility]::referenceLibraryPath;
        $version = [utility]::octopusClientDllVersion;
        $source = [utility]::nugetSource;

        if (!(Test-Path "$octoClientDLLPath")) {
            Write-Host "Installing Octopus.Client for you...";

            Install-Package -Name Octopus.Client -RequiredVersion $version -SkipDependencies -Destination $destination -Force -Verbose -Source $source;

            if (!(Test-Path "$octoClientDLLPath")) {
                Write-Warning "Unable to install Octopus.Client for you. You''ll need to follow the ReadMe.";
                throw "'$octoClientDLLPath' is not valid.";
                return;
            }

            Add-Type -Path $octoClientDLLPath;
            Write-Host "Added Octopus.Client type...";
            return;
        }
    }
    
    [void] verify_octoposh_module () {
        if (!$this.check_command("Set-OctopusConnectionInfo")) {
            Write-Host "Installing Octoposh for you...";
            Install-Module -Name Octoposh -force;
            Write-Host "Importing Octoposh for you...";
            Import-Module Octoposh;

            if (!$this.check_command("Set-OctopusConnectionInfo")) {
                Write-Error "Unable to install Octoposh for you. You''ll need to follow the ReadMe.";
                throw "Octoposh is not installed...";
            }

            Write-Host "Octoposh setup complete...";
        }
    }
    
    [bool] check_command ($cmdName) {
        return [bool](Get-Command -Name "$cmdName" -ErrorAction SilentlyContinue);
    }

    [void] cie_working_directory () {
        $path = [utility]::workingDirectory;

        if (!(Test-Path $path)) {
              New-Item -ItemType Directory -Force -Path $path;
        }
    }
}
