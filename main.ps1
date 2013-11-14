<#

 Name:         Flexpod Toolkit
 Author:       Matthew Oswalt
 Created:      6/10/2013
 Description:  This script is the "main" script in a toolkit designed to automate Flexpod provisioning tasks.

               Currently only tested and verified with the following platforms:
                    *NetApp Release 8.2P2 Cluster-Mode
                    *Cisco UCSM 2.1(3a)
                    *Nexus 5596UP running 6.0(2)N2(2)
                    *Powershell 3.0 or above


               The modules are named according to use case. However, any function in any module can reach into any part of a flexpod for both configuring and retrieving information. 
               For example, the function that creates boot LUNs works by first looking at the service profiles in UCS. 
               In summary, the module named CiscoUCS doesn't necessarily just reach into Cisco UCS.

#>
#####TODO#######
#need to make this script create boot policies in UCS after looking at the Netapp target interfaces

#Modularize:
   #https://www.simple-talk.com/sysadmin/powershell/an-introduction-to-powershell-modules/
   #http://social.technet.microsoft.com/Forums/windowsserver/en-US/941c1a0d-e359-4243-9fc5-82e95c2a4c9d/powershell-v3-and-importmodule-ps1
   #http://msdn.microsoft.com/en-us/library/windows/desktop/dd878340(v=vs.85).aspx
   #http://msdn.microsoft.com/en-us/library/dd901839(v=vs.85).aspx
   #http://msdn.microsoft.com/en-us/library/dd878284(v=vs.85).aspx
   #http://msdn.microsoft.com/en-us/library/dd878340(v=vs.85).aspx
   #http://stackoverflow.com/questions/10283622/load-multiple-modules-psm1-using-a-single-psd1-file
   #http://technet.microsoft.com/library/hh849725.aspx
   #http://stackoverflow.com/questions/14382579/relative-path-in-import-module
   #
   #
   #
   #


#PowerShell v3 or higher if you use the PSScriptRoot variable
#The -Force argument unloads the module first, which is good especially for dev. 
#TODO - find a way to import all scripts in these directories
Import-Module $PSScriptRoot\modules\utility\Netapp.psm1 -Force
Import-Module $PSScriptRoot\modules\utility\VMware.psm1 -Force

#Import-Module $PSScriptRoot\modules\buildout\CiscoUCS.psm1 -Force

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
$organization = "DI_DCA"

#endregion

#region Establish Connections

#Connect to Netapp, suppressing prompt
$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
#Disconnect from Controller First
Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompt
$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
Disconnect-Ucs
Connect-Ucs $UCSipAddr -Credential $ucsmCreds

#endregion

#Create-IGroupsAndLuns

Create-IGroupsAndLuns