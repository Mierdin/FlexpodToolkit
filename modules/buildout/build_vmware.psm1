<#
.SYNOPSIS
Add ESXi Hosts into vCenter Inventory

.DESCRIPTION
Description

.PARAMETER computername
Here, the dotted keyword is followed by a single parameter name. Don't precede that with a hyphen. The following lines describe the purpose of the parameter:

.PARAMETER filePath
Provide a PARAMETER section for each parameter that your script or function accepts.

.EXAMPLE
There's no need to number your examples.

.EXAMPLE
PowerShell will number them for you when it displays your help text to a user.
#> 
# Not ready yet. Use at own risk
function Add-HostsEnMasse {
    for ($i=11; $i -le 50; $i++) {
        $is = $i.ToString()
        add-vmhost "" -user "root" -password "" -Force -Confirm:$false -Location "DCA-CLOUD-HA"
    }
 }
 export-modulemember -function Add-HostsEnMasse


#Create images
function Run-AutoDeployStatefulInstall {
    $imageProfileName = "ESXi55-1331820-CISCO"
    $hostProfileName = "AutoDeployHostProfile"
    $hostClusterName = "DCA-HA" #TODO: Need to acquire this programmatically or derived from a CSV if possible
    $driversDir = "C:\stuff\"

    <#
    PREREQUISITES
       - Need to create a Host Profile, and provide name in "hostProfileName" argument above
       - Configure Host Profile to permit stateful Auto Deploy intstallation with "remote" argument and VMFS overwrite permitted
    #>


    #Add main VMWare software depot
    Add-EsxSoftwareDepot https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml

    #Add Cisco VEM, FNIC, and ENIC drivers.
    ls -path $driversDir -Recurse -Include *.zip | % { Add-EsxSoftwareDepot $_.FullName } #The -Force flag is important - ensures module is unloaded first.

    #TODO: Also need to automate the selection of the newest profile instead of statically calling it out here
    New-EsxImageProfile -cloneprofile ESXi-5.5.0-1331820-standard -name $imageProfileName -Vendor "Cisco"
    
    #Add drivers into Image Profile
    #NOTE - this function will assume you have added all three. Remove below as needed if you don't intend to add.
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName *fnic
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName net-enic
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName cisco-vem*

    # The syntax for the "item" argument is: -Item <image profile>, <cluster>, <host profile>
    # -AllHosts designation is a replacement for "-Pattern". Since we'll be controlling which hosts get AutoDeploy'd through other (UCS) means, we don't need or want VMware to do this filtering.
    New-DeployRule -Name "AutoDeployStateful55" -Item $imageProfileName, $hostClusterName, $hostProfileName -AllHosts
    
    Add-DeployRule -DeployRule AutoDeployStateful55

}
export-modulemember -function Run-AutoDeployStatefulInstall


function Set-VMHostStaticIPs {
    #Use this function at your own risk. This was written to ensure hosts installed via Stateful Autodeploy were still IP'd sequentially and deterministically (i.e. ESXi-01 was given an address of .10, ESXi-10 was .11, etc.)
    #So I would let the hosts get an IP via DHCP, and if hosts were brought online in the right order, the address would be predictable. So I would connect to each, and ensure it was changed to be static, instead of DHCP.

    #Also - ran into a lot of problems trying to run this over a long-distance connection. Some hosts would get IP'd wrong, some wouldn't connect, some would disconnect from vCenter, etc.
    #Best to run this snippet on a server that is very close to the target hosts like a "jump box" or even vCenter itself

    for ($i=1; $i -le 60; $i++) {
        Write-Host "Connecting to $i"
        Connect-VIServer 10.102.40.$i -User "root" -Password "" -Force
        Get-VMHostNetwork | Set-VMHostNetwork -VMKernelGateway 10.102.40.1
        Get-VMHostNetworkAdapter -Name "vmk0" | Set-VMHostNetworkAdapter -dhcp:$false -ip 10.102.40.$i -Subnetmask 255.255.255.0 -Confirm:$false
        Disconnect-VIServer 10.102.40.$i -Confirm:$false
    }
}
export-modulemember -function Set-VMHostStaticIPs

Write-Host "Loaded build_vmware.psm1"