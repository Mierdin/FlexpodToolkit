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
   #/modules/buildout/CiscoUCS.psm1




#PowerShell v3 or higher if you use the PSScriptRoot variable
#The -Force argument unloads the module first, which is good especially for dev. Powershell likes to remember old modules, making your changes not take effect.
#TODO - find a way to import all scripts in these directories
Import-Module $PSScriptRoot\modules\utility\util_netapp.psm1 -Force
Import-Module $PSScriptRoot\modules\utility\util_vmware.psm1 -Force
#Import-Module $PSScriptRoot\modules\buildout\build_ucs.psm1 -Force #Good as a standalone script, but not ready yet, need to make into functions before integrating here
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
$organization = "org"

$VMWipAddr = "10.102.43.16"
$VMWusername = "root"
$VMWpassword = "password"

#endregion

#region Establish Connections

#Connect to Netapp, suppressing prompts
$NASecPass = ConvertTo-SecureString $NApassword -AsPlainText -Force
$NAcred = New-Object System.Management.Automation.PSCredential($NAusername, $NASecPass)
Disconnect from Controller First
Connect-NcController $NAipAddr -credential $NAcred

#Connect to UCSM, suppressing prompts
$UCSSecPass = ConvertTo-SecureString $UCSpassword -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($UCSusername, $UCSSecPass)
Disconnect-Ucs
Connect-Ucs $UCSipAddr -Credential $ucsmCreds

#Connect to vCenter, suppressing prompts
#Disconnect-VIServer
Connect-VIServer $VMWipAddr -User $VMWusername -Password $VMWpassword -Force

#endregion





#There will be a menu structure here in the next release, allowing you to easy and simply select provided cmdlets from a menu




<#

#Random code snippets that are useful, but dont really have a home

for ($i=1; $i -le 60; $i++) {
    $iPlus20 = $i + 20
    Add-DnsServerResourceRecordA -Name ESXi-$i -ZoneName example.com -IPv4Address "10.102.40.$iPlus20"
    Add-DnsServerResourceRecordPtr -Name "$iPlus20" -ZoneName "40.102.10.in-addr.arpa" -PtrDomainName "ESXi-$i.example.com"
}

$SPS = Get-UcsServiceProfile -Type instance -SrcTemplName SPT-ESXi
foreach ($SP in $SPS) {
    $SP | Set-UcsServerPower -State admin-up -Force
    Write-Host "Powered up " $SP.name
    Start-Sleep -s 300
}


This was created as a test to quickly delete and reprovision netapp LUNs for some AutoDeploy hacking
Remove-NcLun -Path "/vol/FC_BootVol1/DCA-ESXi-11_boot" -VserverContext $NAvserver -Force
Remove-NcIgroup -VserverContext $NAvserver -Force -Name "DCA-ESXi-11"

#>







 





