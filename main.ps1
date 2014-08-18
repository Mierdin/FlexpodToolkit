<#
 Name:         Flexpod Toolkit
 Author:       Matthew Oswalt
 Created:      6/10/2013
 Description:  This script is the "main" script in a toolkit designed to automate Flexpod provisioning tasks.
               For more information, and an exhaustive, updated list of dependencies, see https://github.com/Mierdin/FlexpodToolkit

#>


#####TODO#######
#TODO: need to make this script create boot policies in UCS after looking at the Netapp target interfaces
#TODO: Need to Set-PowerCLIConfiguration so that InvalidCertificateAction is updated to accept any and all certificates so logging in can happen seamlessly
#TODO: Really should create vNIC/vHBA placement policy section in UCS
#TODO: Ensure this can handle non-suborg UCS deployments seamlessly

#Import all our modules
ls -path $PSScriptRoot\modules -Recurse -Include *.psm1 | % { Import-Module $_.FullName -Force } #The -Force flag is important - ensures module is unloaded first.
 
#Import all vendor modules 
Add-PSSnapin VMware*
Import-Module CiscoUcsPs
Import-Module DataONTAP
Write-Host "Imported Vendor Cmdlets"

#region VARs

$NAipAddr = ""
$NAusername = ""
$NApassword = ""
$NAportset = "FC_Portset"
$NAvserver = "Infra_Vserver"
$NAvserverRootVol = "root_vol"
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
#$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
#$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
#Disconnect from Controller First
#Disconnect-NcController
#Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompts
#$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
#$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
#Disconnect-Ucs
#Connect-Ucs $UCSipAddr -Credential $ucsmCreds

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
