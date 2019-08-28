<# 
This script conditionaly adds user from an AD group to Octo
#>
param([Parameter(Mandatory)] [string] $aDGroupName);

$ErrorActionPreference = "Stop";

function get_ad_group_members ([Parameter(Mandatory = $true)] $aDGroupName) {
    $serverName = [Utility]::domainControllerName;

    # Fetch ADUSers for the provided Group
    Get-ADGroupMember -Identity $aDGroupName -server $serverName -Recursive |
        Get-ADUser -Property DisplayName, EmailAddress | 
        Select-Object Name, ObjectClass, DisplayName, UserPrincipalName, EmailAddress;    
}

function get_octo_users_all ([Parameter(Mandatory = $true)] $repository) {
    $repository.Users.GetAll();
}

function process_octo_users (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)] $repository, 
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)] $adUsers, 
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)] $allOctoUsers ) {
   
    foreach ($adUser in $adUsers) {
        # Find Octo User by ADUser Email
        $user = $allOctoUsers | Where-Object { $_.EmailAddress -eq $adUser.EmailAddress };
    
        if ($user) {
            Write-Host "Found" $user.DisplayName -ForegroundColor Gray -BackgroundColor Black;
        }
        else {           
            add_octo_user $adUser $repository;                                 
        }
    }
}

function add_octo_user (
    [Parameter(Mandatory = $true)] $adUser, 
    [Parameter(Mandatory = $true)] $repository) {
    
    if ($adUser -and $adUser.EmailAddress) {
        $userToAdd = New-Object Octopus.Client.Model.UserResource;
        $userToAdd.Username = $adUser.UserPrincipalName;
        $userToAdd.DisplayName = $adUser.DisplayName;
        $userToAdd.EmailAddress = $adUser.EmailAddress;
        $userToAdd.IsActive = $true;
        
        $repository.Users.Create($userToAdd);
        Write-Host "Added" $userToAdd.DisplayName -ForegroundColor Green -BackgroundColor Black;
    }
    else {
        Write-Warning "Invalid User";
    }
}

function main {
    Clear-Host;
    
    . '.\Helpers\Utility.ps1';
    $repository = [utility]::new().get_octopus_repository();

    $adUsers = get_ad_group_members $aDGroupName;
    $allOctoUsers = get_octo_users_all $repository;

    process_octo_users $repository $adUsers $allOctoUsers;
}

main;
