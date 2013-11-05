<#

 Name:         Flexpod Toolkit
 Author:       Matthew Oswalt
 Created:      6/10/2013
 Description:  This script is the "main" script in a toolkit designed to automate Flexpod provisioning tasks.

               Currently only tested and verified with the following platforms:
                    *NetApp Release 8.2P2 Cluster-Mode
                    *Cisco UCSM 2.1(3a)
                    *Nexus 5596UP running 6.0(2)N2(2)


               The modules are named according to use case. However, any function in any module can reach into any part of a flexpod for both configuring and retrieving information. 
               For example, the function that creates boot LUNs works by first looking at the service profiles in UCS. 

#>
#####TODO#######
#need to make this script create boot policies in UCS after looking at the Netapp target interfaces

#Modularize:
   #https://www.simple-talk.com/sysadmin/powershell/an-introduction-to-powershell-modules/
   #http://social.technet.microsoft.com/Forums/windowsserver/en-US/941c1a0d-e359-4243-9fc5-82e95c2a4c9d/powershell-v3-and-importmodule-ps1
   #http://msdn.microsoft.com/en-us/library/windows/desktop/dd878340(v=vs.85).aspx
   # 


Import-Module CiscoUcsPs
Import-Module DataONTAP
Import-Module .\modules\Storage.psm1

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
$organization = "root"

#endregion

#region Establish Connections

#Connect to Netapp, suppressing prompt
$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompt
$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
Disconnect-Ucs
Connect-Ucs $UCSipAddr -Credential $ucsmCreds

#endregion









