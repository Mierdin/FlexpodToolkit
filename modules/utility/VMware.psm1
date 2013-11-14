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
