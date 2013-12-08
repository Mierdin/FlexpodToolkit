<#
 Name:         Flexpod Toolkit
 Author:       Matthew Oswalt
 Created:      6/10/2013
 Description:  This script is the "main" script in a toolkit designed to automate Flexpod provisioning tasks.

               Currently only tested and verified with the following platforms:

               Hardware Platforms:
                    *NetApp Release 8.2P2 Cluster-Mode
                    *Cisco UCSM 2.1(3a)
                    *Nexus 5596UP running 6.0(2)N2(2)
                    
               Software Platforms:
                    *Powershell 3.0 or above **REQUIRED**
                    *VMWare vSphere 5.5 **required for some vmware features**
                    *PowerCLI 5.5.0 **required for some vmware features**
                    *Cisco PowerTool 1.0.0.0
                    *Netapp PowerShell Toolkit 3.0.0.90


               The modules are named according to use case. However, any function in any module can reach into any part of a flexpod for both configuring and retrieving information. 
               For example, the function that creates boot LUNs works by first looking at the service profiles in UCS. 
               In summary, the module named CiscoUCS doesn't necessarily just reach into Cisco UCS.
#>


#####TODO#######
#need to make this script create boot policies in UCS after looking at the Netapp target interfaces
#Need to Set-PowerCLIConfiguration so that InvalidCertificateAction is updated to accept any and all certificates so logging in can happen seamlessly


#Must run PowerShell v3 or higher if you use the PSScriptRoot variable
#The -Force argument unloads the module first, which is good especially for dev. Powershell likes to remember old modules, making your changes not take effect.
#TODO - find a way to import all modules found in these directories
Import-Module $PSScriptRoot\modules\utility\util_netapp.psm1 -Force
Import-Module $PSScriptRoot\modules\utility\util_vmware.psm1 -Force
Import-Module $PSScriptRoot\modules\buildout\build_ucs.psm1 -Force
Import-Module $PSScriptRoot\modules\buildout\build_vmware.psm1 -Force
 
Add-PSSnapin VMware*
Import-Module CiscoUcsPs
Import-Module DataONTAP

#region VARs

$NAipAddr = "10.102.0.50"
$NAusername = "admin"
$NApassword = "password"
$NAportset = "fcoe_pset_1"
$NAvserver = "DCA_FC_VS1"
$NAbootVol = "/vol/FC_BootVol1/" #Needs to be of this format, including the forward slashes. LUN will be appended without any slashes

$UCSipAddr = "10.102.1.5"
$UCSusername = "admin"
$UCSpassword = "password"
$organization = "DCA"

$VMWipAddr = "10.102.43.16"
$VMWusername = "admin"
$VMWpassword = "password"

$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

#endregion

#region Establish Connections

#Connect to Netapp, suppressing prompts
$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
#Disconnect from Controller First
#Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompts
$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
Disconnect-Ucs
Connect-Ucs $UCSipAddr -Credential $ucsmCreds

#Connect to vCenter, suppressing prompts
#Disconnect-VIServer
#Connect-VIServer $VMWipAddr -User $VMWusername -Password $VMWpassword -Force

#TODO: need to address - WARNING: THE DEFAULT BEHAVIOR UPON INVALID SERVER CERTIFICATE WILL CHANGE IN A FUTURE RELEASE. To ensure scripts are not affected by the change, use Set-PowerCLIConfiguration to set a value for the InvalidCertificateAction option.

#endregion













#There will be a menu structure here in the next release, allowing you to easy and simply select provided cmdlets from a menu






#Time to show off
Write-Host "Script completed in: " $Elapsed.Elapsed
     


 





