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
#TODO: need to make this script create boot policies in UCS after looking at the Netapp target interfaces
#TODO: Need to Set-PowerCLIConfiguration so that InvalidCertificateAction is updated to accept any and all certificates so logging in can happen seamlessly
#TODO: Need to consider the process to add a zero programmatically (i.e. ESXi-01 vs ESXi-1). Need to figure out where this kind of thing would need to be applied, as well as consider the pros and cons of doing this.
        #big thing is when creating service profiles, you have to provide a prefix. If you just say "ESXi-" then it will start with "ESXi-1". There is no assumption about length. This length is what you have to impart.
#TODO: As a best practice, should figure out a way to hide all output and then create your own. The script will look a lot better.
#TODO: Figure out the "unapproved verbs" error. Also output something that lets the user know that modules are being imported
#TODO: Really should create vNIC/vHBA placement policy section in UCS
#TODO: How to handle non-suborg deployments
#TODO: Be more flexible with igroup/LUN/SP naming. And/or maybe make a naming scheme more obvious. See earlier todo about SP numbering.
#TODO: Derive configuration entirely from YAML file instead of here in the script. Make this a black box. Allow users to turn off netapp/UCS/vmware stuff in teh configuration as well.
#TODO Consider Python for this - only thing missing is the Python bindings for Netapp. May consider writing them yourself.

#Must run PowerShell v3 or higher if you use the PSScriptRoot variable
#The -Force argument unloads the module first, which is good especially for dev. Powershell likes to remember old modules, making your changes not take effect.
#TODO - maybe import all modules found in these directories so you don't have to update this when adding new modules. Is there a hot-pluggable architecture for PoSH or Python for these kind of modules?
Import-Module $PSScriptRoot\modules\utility\util_netapp.psm1 -Force
#Import-Module $PSScriptRoot\modules\utility\util_vmware.psm1 -Force

#Import-Module $PSScriptRoot\modules\buildout\build_ucs.psm1 -Force
#Import-Module F:\Dropbox\Code\Powershell\FlexpodToolkit\modules\buildout\build_ucs.psm1 -Force

#Import-Module $PSScriptRoot\modules\buildout\build_vmware.psm1 -Force
 

 
 
#Add-PSSnapin VMware*
Import-Module CiscoUcsPs
Import-Module DataONTAP
Write-Host "Imported Vendor Cmdlets"

#region VARs

$NAipAddr = ""
$NAusername = ""
$NApassword = ""
$NAportset = ""
$NAvserver = ""
$NAvserverRootVol = ""
$NAbootVol = "/vol/esxi_boot/" #Needs to be of this format, including the forward slashes. LUN will be appended without any slashes

$UCSipAddr = ""
$UCSusername = ""
$UCSpassword = ""
$organization = ""  
$mgmt_ippoolstart = "1.1.1.2"
$mgmt_ippoolfinish = "1.1.1.3"
$mgmt_ippoolgw = "1.1.1.1"

$VMWipAddr = ""
$VMWusername = ""
$VMWpassword = ""

#Begin stopwatch to see how long script runs.
$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

#endregion

#region Establish Connections to Infrastructure

#Connect to Netapp, suppressing prompts
$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
#Disconnect from Controller First
Disconnect-NcController
Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompts
$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
Disconnect-Ucs
Connect-Ucs $UCSipAddr -Credential $ucsmCreds

#Connect to vCenter, suppressing prompts
#Disconnect-VIServer
#Set-PowerCliConfiguration -InvalidCertificateAction Ignore
#Connect-VIServer $VMWipAddr -User $VMWusername -Password $VMWpassword -Force

#endregion

#

#Generate-SPsFromTemplate
#Create-VMKonAllHosts -locationFilter DCBCLOUDORC01 -newSubnet "10.104.41." -subnetMask "255.255.255.0" -strPG "vMotion" -vMotionEnabled:$True -VMKMTU 9000 -addVmnic1:$False
#Create-VMKonAllHosts -locationFilter DCBCLOUDORC01 -newSubnet "10.104.32." -subnetMask "255.255.255.0" -strPG "l3_control" -vMotionEnabled:$False -VMKMTU 1500 -addVmnic1:$False
#Create-VMKonAllHosts -locationFilter DCBCLOUDORC01 -newSubnet "10.104.160." -subnetMask "255.255.240.0" -strPG "NFS" -vMotionEnabled:$False -VMKMTU 9000 -addVmnic1:$False

#Migrate-VMKandUplinks -locationFilter DCBCLOUDORC01

#Update-Igroup

#Add-NFSDataStore 

#Update-NetappCiscoBFS
#Generate-FCSwitchConfig

#Get-VMHost -Location DCACLOUDRESCL04 | foreach {
#    $_ | Get-VMHostNetworkAdapter -name vmk3 | Set-VMHostNetworkAdapter -Mtu 9000 -Confirm:$false
#}

# ***** UCS TASKS  *****
#UCS-Housekeeping
#Create-VLANsAndVSANs
#Create-ResourcePools
#Create-StaticPolicies
#Create-BootPolicy
#Create-vNICvHBATemplates
#Create-SPTemplates
#Generate-SPsFromTemplate

#There will be a menu structure here in an upcoming release, allowing you to easy and simply select provided cmdlets from a menu

#Time to show off
Write-Host "Script completed in: " $Elapsed.Elapsed
