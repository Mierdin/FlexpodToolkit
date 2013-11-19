
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
        
    #Must use below format for stating subnet of new VMK ports (everything but the numbers in the last octet - that's generated automatically)
    $newSubnet = "10.102.32."
    $subnetMask = "255.255.255.0"
    $strPG = "1KV_CTRL"
 
    #Using the $_ method here, equivalent to the "this" nomenclature in java and .net
    Get-VMHost | foreach {
    
        #pull address of management VMK to use as a baseline for new address (use the same last octet)
        $thisVMK = $_ | Get-VMHostNetworkAdapter -name vmk0
 
        #Retrieve last octet, without decimal
        $lastOctet = $thisVMK.IP.substring($thisVMK.IP.LastIndexOf(".") + 1, $thisVMK.IP.Length - $thisVMK.IP.LastIndexOf(".") - 1)
 
        $thisIPaddr = [string]::Concat($newSubnet, $lastOctet.ToString())
 
        New-VMHostNetworkAdapter -VMHost $_ -VirtualSwitch vSwitch0 -PortGroup $strPG -IP $thisIPaddr -SubnetMask $subnetMask -VMotionEnabled:$True
        $PG = Get-VirtualPortgroup -Name $strPG -VMHost $_ 

        #Need to create a vMotion port group first, else this line will error out.
        #If you're adding it to a "mode access" port group in the 1000v, it doesn't matter. That's why I haven't fixed it yet.
        #Set-VirtualPortGroup -VirtualPortGroup $PG -VlanId 241
   
       Write-Host "Finished with host " $thisVMK.IP 
    }

}
export-modulemember -function Create-VMKonAllHosts

<#
function Migrate-VMKandUplinks {

#NOT EVEN CLOSE TO WORKING

    $VMHost = Read-Host "Enter Hostname to Migrate"
    $VDSwitch = Read-Host "Enter VDSwitch Name"
    $VSwitch = Read-Host "Enter Standard VSwitch Name"

    #Get VMhost object data
    Get-VMHost $VMHost | foreach {

        #Remove 1 uplink and migrate to standard
        $VMhostObj | Get-VMHostNetworkAdapter -Physical -Name "vmnic1" | Remove-VDSwitchPhysicalNetworkAdapter -Confirm:$false
        $VSwitch = $VMhostObj | Get-VirtualSwitch -Name $VSwitch

        #Get physical adapter to move
        $vmhostadapter = $VMhostObj | Get-VMHostNetworkAdapter -Physical -Name vmnic1 
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VSwitch -VMHostVirtualNic $vmk0,$vmk1 -VMHostPhysicalNic $vmhostadapter -Confirm:$false

        #Swing Second Physical Interface Over
        $VMhostObj | Get-VMHostNetworkAdapter -Physical -Name "vmnic0" | Remove-VDSwitchPhysicalNetworkAdapter -Confirm:$false

        $vmhostadapter = $VMhostObj | Get-VMHostNetworkAdapter -Physical -Name vmnic0
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $VSwitch -VMHostPhysicalNic $vmhostadapter -Confirm:$false

        # Get Vmotion and Management Virtual Adapters
        $vmk0 = Get-VMHostNetworkAdapter -vmhost $vmhostobj -name vmk0
        $vmk1 = Get-VMHostNetworkAdapter -vmhost $vmhostobj -name vmk1

        # Add 1 physical adapter and migrate Management/Vmotion
        
        #Remove from VDS
        Get-VDSwitch $VDSwitch | Remove-VDSwitchVMHost -VMHost $VMhostObj -Confirm:$false
    }
}
export-modulemember -function Migrate-VMKandUplinks



function ManualUploadVEM {

#ALSO NOWHERE CLOSE TO WORKING and probably won't implement - prefer to load drivers in via AutoDeploy

        #########START CODE
        if(-not (Get-pssnapin | Where-Object {$_.Name -eq "VMware.VimAutomation.Core"})) {
            Add-PSSnapin VMware.VimAutomation.Core
        }
 
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
export-modulemember -functionManualUploadVEM
#>