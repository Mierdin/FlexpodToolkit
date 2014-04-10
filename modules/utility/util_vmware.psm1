function Add-NFSDataStore {
    Get-VMHost -Location DCBCLOUDORC01 | foreach {
        $_ | New-Datastore -Nfs:$true -Name SAS01 -NfsHost 10.104.160.11 -Path "/SAS01"
        $_ | New-Datastore -Nfs:$true -Name SAS02 -NfsHost 10.104.160.12 -Path "/SAS02"
        $_ | New-Datastore -Nfs:$true -Name SAS03 -NfsHost 10.104.160.13 -Path "/SAS03"
        $_ | New-Datastore -Nfs:$true -Name SAS04 -NfsHost 10.104.160.14 -Path "/SAS04"
        $_ | New-Datastore -Nfs:$true -Name SATA01 -NfsHost 10.104.160.11 -Path "/SATA01"
    }
}
export-modulemember -function Add-NFSDataStore

function Set-MaintenanceMode {
    #Probably not going to do this, it's a one-liner as is
    #http://aravindsivaraman.wordpress.com/2012/07/06/set-maintenance-mode-using-power-cli/
}
export-modulemember -function Set-MaintenanceMode



function Delete-VMKonAllHosts {
        param(
        [string] $vmkName
        )

    #Using the $_ method here, equivalent to the "this" nomenclature in java and .net
    Get-VMHost | foreach {
       Get-VMHostNetworkAdapter -Name $vmkName | Remove-VMHostNetworkAdapter
    }
}
export-modulemember -function Delete-VMKonAllHosts


function Create-VMKonAllHosts {
    
    param(
        [parameter(Mandatory=${true})][string]$locationFilter,
        [parameter(Mandatory=${true})][string]$newSubnet,
        [parameter(Mandatory=${true})][string]$subnetMask,
        [parameter(Mandatory=${true})][string]$strPG,
        [parameter(Mandatory=${true})][bool]$vMotionEnabled,
        [parameter(Mandatory=${true})][int]$VMKMTU,
        [parameter(Mandatory=${true})][bool]$addVmnic1
    )

    #Using the $_ method here, equivalent to the "this" nomenclature in java and .net
    Get-VMHost -Location $locationFilter | foreach {

        #pull address of management VMK to use as a baseline for new address (use the same last octet)
        $thisVMK = $_ | Get-VMHostNetworkAdapter -name vmk0
 
        #Retrieve last octet, without decimal
        $lastOctet = $thisVMK.IP.substring($thisVMK.IP.LastIndexOf(".") + 1, $thisVMK.IP.Length - $thisVMK.IP.LastIndexOf(".") - 1)
        $thisIPaddr = [string]::Concat($newSubnet, $lastOctet.ToString())

        New-VMHostNetworkAdapter -VMHost $_ -VirtualSwitch vSwitch0 -PortGroup $strPG -IP $thisIPaddr -SubnetMask $subnetMask -VMotionEnabled:$vMotionEnabled -Mtu $VMKMTU
        $PG = Get-VirtualPortgroup -Name $strPG -VMHost $_ 

        if ($addVmnic1) {
            #Below lines allow you to also migrate a second NIC into the vswitch if not done during install. Comment out to prevent this.
            ##CAREFUL - this messes with hardware required for host management. Use with caution.
            $mainVswitch = Get-VirtualSwitch -VMHost $_ -Name "vSwitch0"
            $mainVswitch | Set-VirtualSwitch -Nic "vmnic0","vmnic1" -Confirm:$false
            $mainVswitch | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive "vmnic1" -Confirm:$false
        }

        #tags a VLAN on a port group. I'm doing the 1000v with "mode access" port profiles so uneeded for now.
        #Set-VirtualPortGroup -VirtualPortGroup $PG -VlanId 241

    }

}
export-modulemember -function Create-VMKonAllHosts

function Enable-SSH {
    Get-VMHost -Location DCBCLOUDORC01 | Foreach {
      #This will start the SSH service on all hosts
      Stop-VMHostService -Confirm:$false -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} )
    }
}
export-modulemember -function Enable-SSH



function Migrate-VMKandUplinks {   

    param(
        [parameter(Mandatory=${true})][string]$locationFilter
    )

    #$VMHost = Read-Host "Enter Hostname to Migrate"
    $VDSwitch = "DCB-CLOUD-1KVVSM"
    #$VSwitch = Read-Host "Enter Standard VSwitch Name"

    #Get VMhost object data
    Get-VMHost -Location $locationFilter | foreach {

        #pull address of management VMK to use as a baseline for new address (use the same last octet)
        $thisVMK = $_ | Get-VMHostNetworkAdapter -name vmk0
        $lastOctet = $thisVMK.IP.substring($thisVMK.IP.LastIndexOf(".") + 1, $thisVMK.IP.Length - $thisVMK.IP.LastIndexOf(".") - 1)     #Retrieve last octet, without decimal

        #Add host into VDS
        #Add-VDSwitchVMHost -VMHost $_ -VDSwitch $VDSwitch

        $vmnic2 = Get-VMHostNetworkAdapter -Physical -Name "vmnic2" -VMHost $_
        $vmnic3 = Get-VMHostNetworkAdapter -Physical -Name "vmnic3" -VMHost $_

        #CAREFUL HERE - I am using separate NICs that are unused until migrated, so I can force migration like this. YMMV and be careful!
        #Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmnic2 -DistributedSwitch $VDSwitch -Confirm:$false
        #Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmnic3 -DistributedSwitch $VDSwitch -Confirm:$false
            
        ########$vmk0 = Get-VMHostNetworkAdapter -vmhost $_ -name vmk0
        #$vmk1 = Get-VMHostNetworkAdapter -vmhost $_ -name vmk1
        #$vmk2 = Get-VMHostNetworkAdapter -vmhost $_ -name vmk2
        ########$vmk3 = Get-VMHostNetworkAdapter -vmhost $_ -name vmk3
        $vmk4 = Get-VMHostNetworkAdapter -vmhost $_ -name vmk4

        #$VDPortGroup = Get-VDPortGroup -Name "vMotion" -VDSwitch $VDSwitch
        #Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $VDSwitch -VMHostVirtualNic $vmk1 -Confirm:$false -VMHostPhysicalNic $vmnic2,$vmnic3 -VirtualNicPortgroup $VDPortGroup

        #$VDPortGroup = Get-VDPortGroup -Name "l3_control" -VDSwitch $VDSwitch
        #Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $VDSwitch -VMHostVirtualNic $vmk2 -Confirm:$false -VMHostPhysicalNic $vmnic2,$vmnic3 -VirtualNicPortgroup $VDPortGroup
            
        $VDPortGroup = Get-VDPortGroup -Name "NFS" -VDSwitch $VDSwitch
        Add-VDSwitchPhysicalNetworkAdapter -DistributedSwitch $VDSwitch -VMHostVirtualNic $vmk4 -Confirm:$false -VMHostPhysicalNic $vmnic2,$vmnic3 -VirtualNicPortgroup $VDPortGroup
        
    }
}
export-modulemember -function Migrate-VMKandUplinks

function Install-VEMnoVUM {
     function Select-Folder($message='Select a folder', $path = 0) {  
        $object = New-Object -comObject Shell.Application   
 
        $folder = $object.BrowseForFolder(0, $message, 0, $path)  
        if ($folder -ne $null) {  
            $folder.self.Path  
        }  
    }
 
    $hostip=read-host "host ip address"
    Connect-ViServer $hostip
 
    $esxhosts = get-vmhost | get-datastore | sort Name
 
    $PatchDatastore = @()
 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
 
    $PatchForm = New-Object System.Windows.Forms.Form 
    $PatchForm.Text = "Select patch datastore"
    $PatchForm.Size = New-Object System.Drawing.Size(320,300) 
    $PatchForm.StartPosition = "CenterScreen"
 
    $PatchForm.KeyPreview = $True
 
    $PatchForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
        {
            foreach ($PatchItem in $PatchListbox.SelectedItems)
                {$PatchDatastore += $PatchItem}
            $PatchForm.Close()
        }
        })
 
    $PatchForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
        {$PatchForm.Close()}})
 
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(75,220)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
 
    $OKButton.Add_Click(
       {
            foreach ($script:PatchItem in $PatchListbox.SelectedItems)
                {$script:PatchDatastore += $script:PatchItem}
            $PatchForm.Close()
       })
 
    $PatchForm.Controls.Add($OKButton)
 
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150,220)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({$PatchForm.Close()})
    $PatchForm.Controls.Add($CancelButton)
 
    $PatchLabel = New-Object System.Windows.Forms.Label
    $PatchLabel.Location = New-Object System.Drawing.Size(10,20) 
    $PatchLabel.Size = New-Object System.Drawing.Size(280,20) 
    $PatchLabel.Text = "Select patch datastore from the list below:"
    $PatchForm.Controls.Add($PatchLabel) 
 
    $PatchListbox = New-Object System.Windows.Forms.Listbox 
    $PatchListbox.Location = New-Object System.Drawing.Size(10,40) 
    $PatchListbox.Size = New-Object System.Drawing.Size(260,20) 
 
    $PatchListbox.SelectionMode = "MultiExtended"
 
    foreach($esxhost in $esxhosts){
    [void] $PatchListbox.Items.Add("$esxhost")
    }
 
    $PatchListbox.Height = 180
    $PatchForm.Controls.Add($PatchListbox) 
    $PatchForm.Topmost = $True
 
    $PatchForm.Add_Shown({$PatchForm.Activate()})
    [void] $PatchForm.ShowDialog()
 
    $DS = Get-VMHost -Name $hostip | Get-Datastore $PatchDatastore
 
    $localpatchdir=Select-Folder "Select the folder where your patch is located"
    $hostpatchdir=Split-Path $localpatchdir -Leaf
 
    Copy-DatastoreItem $localpatchdir\ $DS.DatastoreBrowserPath -Recurse
    Get-VMHost $hostip | Set-VMHost -State Maintenance
 
    Get-VMHost $hostip | Install-VMHostPatch -Hostpath "/vmfs/volumes/$DS/$hostpatchdir/metadata.zip"
 
    #Uncomment to reboot
    #restart-vmhost -vmhost $hostip -confirm:$false
    ####################################
}
#Not ready, so not making available yet.
#export-modulemember -function Enable-SSH

Write-Host "Loaded util_vmware.psm1"