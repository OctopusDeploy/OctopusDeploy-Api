<#
.Synopsis
   Updates the Step Templates used on Deployment Processes to the latest versions
.DESCRIPTION
   Step templates can be updated from the library on Octopus, but that doesnt mean that the Deployment processes using that template will start using the latest version right away. Normally, the user would have to update the step template on each deployment process manually. This script takes care of that.
.EXAMPLE
   Update-StepTemplatesOnDeploymentProcesses -ActionTemplateID "ActionTemplates-3" -OctopusURI "http://localhost" -APIKey "API-RLMWLZBPMX5DRPLCRNZETFS4HA"
.EXAMPLE
   Update-StepTemplatesOnDeploymentProcesses -AllActionTemplates -OctopusURI "http://Octopusdeploy.MyCompany.com" -APIKey "API-TSET42BPMX5DRPLCRNZETFS4HA"
.LINK
   Github project: https://github.com/Dalmirog/OctopusSnippets
#>
Function Update-StepTemplatesOnDeploymentProcesses
{
    [CmdletBinding()]        
    Param
    (
        # Action Template ID. Use when you only want to update the deployment processes that only use this Action Template.
        [Parameter(Mandatory=$true,ParameterSetName= "SingleActionTemplate")]
        [string]$ActionTemplateID,

        # If used, all the action templates will be updated on all the deployment processes.
        [Parameter(Mandatory=$true, ParameterSetName= "AllActionTemplates")]
        [switch]$AllActionTemplates,

        # Octopus instance URL
        [Parameter(Mandatory=$true)]
        [string]$OctopusURI,

        # Octopus API Key. How to create an API Key = http://docs.octopusdeploy.com/display/OD/How+to+create+an+API+key
        [Parameter(Mandatory=$true)]
        [string]$APIKey,

        # Full path of Octopus.Client.dll. You can get it from https://www.nuget.org/packages/Octopus.Client/
        [Parameter(Mandatory=$false)]
        $OctopusClientDLLPath = "C:\Program Files\Octopus Deploy\Tentacle\octopus.client.dll" #Default Tentacle install dir
    )

    Begin
    {
        if(!(Test-Path "$OctopusClientDLLPath")){

            Write-Warning "Octopus Tentacle doesnt seem to be insalled on '$OctopusClientDLLPath'. Please use the parameter -OctopusClientDLLPath to specify the path where the Octopus Tentacle was installed. `nTIP - This path should be the parent directory of: Octopus.Client.dll"             
            break 
        }
        else{
            Add-Type -Path $OctopusClientDLLPath -ErrorAction SilentlyContinue
        }
        $headers = @{"X-Octopus-ApiKey"="$($apikey)";}

        #Create endpoint connection
        $endpoint = new-object Octopus.Client.OctopusServerEndpoint "$($OctopusURI)","$($apikey)"
        $repository = new-object Octopus.Client.OctopusRepository $endpoint


    }
    Process
    {
        If($PSCmdlet.ParameterSetName -eq "SingleActionTemplate"){
            $templates = Invoke-WebRequest -Uri "$($OctopusURI)/api/actiontemplates/$ActionTemplateID" -Method Get -Headers $headers | select -ExpandProperty content| ConvertFrom-Json
        }
        
        Else{$templates = Invoke-WebRequest -Uri "$($OctopusURI)/api/actiontemplates/All" -Method Get -Headers $headers | select -ExpandProperty content| ConvertFrom-Json}
        
        Foreach ($template in $templates){

            $usage = Invoke-WebRequest -Uri "$($OctopusURI)/api/actiontemplates/$($template.ID)/usage" -Method Get -Headers $headers | select -ExpandProperty content | ConvertFrom-Json
        
            #Getting all the DeploymentProcesses that need to be updated
            $deploymentprocesstoupdate = $usage | ? {$_.version -ne $template.Version}

            write-host "Template: $($template.name)" -ForegroundColor Magenta

            If($deploymentprocesstoupdate -eq $null){

                Write-host "`t--All deployment processes up to date" -ForegroundColor Green

            }

            Else{

                Foreach($d in $deploymentprocesstoupdate){

                    #Getting DeploymentProcess obj
                    $process = $repository.DeploymentProcesses.Get($d.DeploymentProcessId)

                    #Finding the step that uses the step template
                    $steps = $process.Steps | ?{$_.actions.properties.values.value -eq $template.Id}

                    try{

                        foreach($step in $steps){

                            Write-host "`t--Updating Step [$($step.name)] of project [$($d.projectname)]" -ForegroundColor Yellow

                            $step.Actions.properties.'Octopus.Action.Script.Scriptbody' = $template.Properties.'Octopus.Action.Script.ScriptBody'

                            #Start NotProudOfThisLogicButItWorks
                            $properties = $step.Actions.properties | select -ExpandProperty keys | ?{$_ -notlike "Octopus.action*"}

                            #Comparing properties of current step and deleting the
                            #ones that are not in the latest version of the step template                            
                            foreach($p in $properties){
                                if($p -notin $template.parameters.name){
                                    $null = $Step.actions.properties.remove($p)
                                }
                            }

                            #Comparing the latest properties of the step template
                            #and adding the ones missing on the step
                            foreach ($p in $template.Parameters){
                                If($p.name -notin $properties){
                                    $null = $step.Actions.properties.add($p.name,$p.Defaultvalue)
                                }
                            }
                            #End NotProudOfThisLogicButItWorks
                                            
                            #Updating the Template.Version property to the latest
                            $step.Actions.properties.'Octopus.Action.Template.version' = $template.Version                                                      
                        }
                        If($repository.DeploymentProcesses.Modify($process))
                        {
                            Write-host "`t--Project updated: $($d.projectname)" -ForegroundColor Green
                        }
                    }                    

                    catch{
                        Write-Error "Error updating Process template for Octopus project: $($d.projectname)"
                        write-error $_.Exception.message            
                    }
        
                }
           
            }
        }
        
    }
    End
    {
    }
}

#Update-StepTemplatesOnDeploymentProcesses -OctopusURI $OctopusURL -APIKey $OctopusAPIKey -AllActionTemplates