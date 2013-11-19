
<# Designed to add hosts en masse, but not ready yet. Will drive this configuration based on UCS service profile names
function Run-AutoDeployStatefulInstall {
    for ($i=11; $i -le 50; $i++) {
        $is = $i.ToString()
        add-vmhost "" -user "root" -password "" -Force -Confirm:$false -Location "DCA-CLOUD-HA"
    }
 }
 export-modulemember -function Run-AutoDeployStatefulInstall
#>

function Run-AutoDeployStatefulInstall {
    $imageProfileName = "ESXi55-1331820-CISCO"
    $hostProfileName = "AutoDeployHostProfile"
    $hostClusterName = "DCA-HA" #TODO: Need to acquire this programmatically or derived from a CSV if possible

    #Create Host Profile

    #Configure Host Profile to permit stateful Auto Deploy intstallation with "remote" argument and VMFS overwrite permitted

    #Add main VMWare software depot
    Add-EsxSoftwareDepot https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml

    #Also add new drivers for Cisco stuff, etc. 
    #TODO: Need to build out more so it iterates through a directory instead of defining statically
    Add-EsxSoftwareDepot C:\stuff\fnic_driver_1.5.0.45-offline_bundle-1349670.zip
    Add-EsxSoftwareDepot C:\stuff\enic-2.1.2.38-offline_bundle-1349680.zip
    Add-EsxSoftwareDepot C:\stuff\VEM550-201309162104-BG-release.zip

    #TODO: Also need to automate the selection of the newest profile instead of statically calling it out here
    New-EsxImageProfile -cloneprofile ESXi-5.5.0-1331820-standard -name $imageProfileName -Vendor "Cisco"
    
    #Add drivers into Image Profile
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName *fnic
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName net-enic
    Add-ESXSoftwarePackage -ImageProfile $imageProfileName cisco-vem*

    # The syntax for the "item" argument is: -Item <image profile>, <cluster>, <host profile>
    # -AllHosts designation is a replacement for "-Pattern". Since we'll be controlling which hosts get AutoDeploy'd through other (UCS) means, we don't need or want VMware to do this filtering.
    New-DeployRule -Name "AutoDeployStateful55" -Item $imageProfileName, $hostClusterName, $hostProfileName -AllHosts
    
    Add-DeployRule -DeployRule AutoDeployStateful55

}
export-modulemember -function Run-AutoDeployStatefulInstall

#Create images
function Set-VMHostStaticIPs {
    #Ran into a lot of problems trying to run this over a long-distance connection. Some hosts would get IP'd wrong, some wouldn't connect, some would disconnect from vCenter, etc.
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


function Select-Folder($message='Select a folder', $path = 0) {  
    $object = New-Object -comObject Shell.Application   
 
    $folder = $object.BrowseForFolder(0, $message, 0, $path)  
    if ($folder -ne $null) {  
        $folder.self.Path  
    }  

}
