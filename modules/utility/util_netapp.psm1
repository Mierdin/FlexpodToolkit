<#
.SYNOPSIS
"Trues up" an initiator group.

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
function Update-Igroup {
#TODO: Also need to make this extensible. Either allow multiple igroups and customization based on which SPs get added to which igroup, or at least allow a narrowing down of igroup members so that you can do them manually one at a time using this function.

    #We only want Service Profile Instances, not Templates
    $serviceProfiles = Get-UcsServiceProfile -Type instance -Org $organization

    #Iterate through Service Profiles, creating boot luns and igroups, mapping as you go
    foreach ($SP in $serviceProfiles) {

        #Populate array with existing vHBAs on this service profile
        $vHBAs = $SP | Get-UcsVhba

            #Iterate through each vHBA, and add each WWPN to this igroup
            foreach ($vHBA in $vHBAs) {
                Write-Host "Adding WWPN " $vHBA.Addr
                Add-NcIgroupInitiator -Initiator $vHBA.Addr -Name Cloud -vserver $NAvserver
            }
    }

 #Use this function to "true up" an igroup so that if you add servers, you can add access to new blades without any conflicts, or manual intervention. Same idea as BFS function but catered torwards shared storage   
 #Would be nice to provide an easy way to exclude certain servers/WWPNs so that you don't have to create a single big igroup, in case you want to mask certain groups or clusters separately (i.e. management clusters)
}
export-modulemember -function Update-Igroup



function Get-BootTargets {
    Get-NcFcpInterface
    #Gotta select one WWPN per node - gotta find out how to correspond target address with node name
}
export-modulemember -function Get-BootTargets

function Create-vServer {
    $newVServer = New-NcVserver -Name $NAvserver -RootVolume $NAvserverRootVol -RootVolumeAggregate "aggr1_DCB6250_02_SATA" -RootVolumeSecurityStyle UNIX -NameServerSwitch nis
    Set-NcVserver -Name $NAvserver -DisallowedProtocols iscsi,nfs 
}
export-modulemember -function Create-vServer




<#
.SYNOPSIS
"Trues up" the BFS configuration on a Netapp array to work with Cisco UCS.

.DESCRIPTION
Reaches into a Cisco UCS Instance, and iterates through every service profile, creating Netapp initiator groups for each one, and then putting each service profile's vHBA's WWPNs in the respective initiator groups.

.PARAMETER computername
Here, the dotted keyword is followed by a single parameter name. Don't precede that with a hyphen. The following lines describe the purpose of the parameter:

.PARAMETER filePath
Provide a PARAMETER section for each parameter that your script or function accepts.

.EXAMPLE
There's no need to number your examples.

.EXAMPLE
PowerShell will number them for you when it displays your help text to a user.
#>
function Update-NetappCiscoBFS {

    #Pull all service profiles in the selected org
    $serviceProfiles = Get-UcsServiceProfile -Type instance -Org $organization

    #Iterate through Service Profiles, creating boot luns and igroups, mapping as you go
    foreach ($SP in $serviceProfiles) {

        #create path to LUN 
        $LUNPath = $NAbootVol + $SP.name + "_boot"

        #check to see if lun by this path already exists
        if (Get-NcLun -path  $LUNPath -Vserver $NAvserver) {
            Write-Host "LUN already exists: " $SP.Name    
        } Else {
            #Need to finish flushing out this line
            New-NcLun -path  $LUNPath -Size 10g -OsType vmware -Unreserved -vserver $NAvserver
        }

        #Populate array with existing vHBAs on this service profile
        $vHBAs = $SP | Get-UcsVhba

        #check to see if igroup by this name already exists
        if (Get-NcIgroup -name $SP.Name) {
            Write-Host "igroup already exists: " $SP.Name

        } Else {
            #Create the igroup first        
            Write-Host "Creating igroup named " + $SP.Name
            $newIgroup = New-NcIgroup -name $sp.Name -protocol fcp -portset $NAportset -type VMware -vserver $NAvserver

            #Iterate through each vHBA, and add each WWPN to this igroup
            foreach ($vHBA in $vHBAs) {
                Write-Host "Adding WWPN " $vHBA.Addr
                Add-NcIgroupInitiator -Initiator $vHBA.Addr -Name $SP.Name -vserver $NAvserver
            }

            #Adds the mapping at the tail end. Kept inside this if statement so it only ran on igroups that were created by this script, not existing ones
            Add-NcLunMap -Path $LUNPath -InitiatorGroup $newIgroup.Name -vserver $NAvserver
        }
    }
}
export-modulemember -function Update-NetappCiscoBFS

<#
.SYNOPSIS
Creates a Cisco NX-OS configuration snippet for zoning and aliases

.DESCRIPTION
Reaches into Cisco UCS, and either retrun

.PARAMETER FabAWWPNs
Provide a string array of all WWPNs on fabric A that you wish to include as targets in each zone.

.PARAMETER FabBWWPNs
Provide a string array of all WWPNs on fabric B that you wish to include as targets in each zone.

.PARAMETER SPfilter
Provide the name of a service profile template here to only include service profiles spawned from that template in the zoning configuration.
Do not provide this argument if you simply wish to include all service profiles.

.EXAMPLE
There's no need to number your examples.
#>
function Generate-FCSwitchConfig {

    #param(
    #    [parameter(Mandatory=${true})][string[]]$FabAWWPNs,
    #    [parameter(Mandatory=${true})][string[]]$FabBWWPNs,
    #    [parameter(Mandatory=${false})][string]$SPfilter
    #)

    $WWPNTableFabA = $null
    $WWPNTableFabA = @{}
    $WWPNTableFabB = $null
    $WWPNTableFabB = @{}


    #We only want Service Profile Instances, not Templates
    $serviceProfiles = Get-UcsServiceProfile -Type instance -Org $organization

    #Iterate through Service Profiles, creating boot luns and igroups, mapping as you go
    foreach ($SP in $serviceProfiles) {

        #Populate array with existing vHBAs on this service profile
        $vHBAs = $SP | Get-UcsVhba

        #Iterate through each vHBA, and add each WWPN to this igroup
        foreach ($vHBA in $vHBAs) {
            #Adding WWPN and name to hash table for later config generation
            if($vHBA.SwitchId -eq "A") {
                $WWPNTableFabA.Add($SP.Name + "_" + $vHBA.Name, $vHBA.Addr)
            } else {
                $WWPNTableFabB.Add($SP.Name + "_" + $vHBA.Name, $vHBA.Addr)
            }

        }
    }

    $ConfigFile = Read-Host "Enter path and file name for the config file"
    New-Item -ItemType file $ConfigFile -Force

    Add-Content $ConfigFile "!Fabric A Configuration"

    Add-Content $ConfigFile "device-alias database"
    $WWPNTableFabA.GetEnumerator() | Sort-Object Name | % { 
        $configLine = ("device-alias name " + $($_.key) + " pwwn " + $($_.value))
        Add-Content $ConfigFile $configLine
    }
    Add-Content $ConfigFile "device-alias commit"

    Add-Content $ConfigFile "!"

    #create zones 
    $WWPNTableFabA.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("zone name " + $($_.key) + " vsan 435")
        Add-Content $ConfigFile ("member pwwn " + $($_.value))

        #TODO: Need to add an argument to this function that pulls the four values from the UCS boot policy and uses them
        #TODO: Actually, can't do that since the boot policy only has two WWPNs per fabric, not 4. Need to figure a way to correlate UCS wth the "get-boottargets" function so that you know that the WWPNs in teh boot configuration will be in this zoning config.
        Add-Content $ConfigFile "member pwwn 20:01:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:03:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:05:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:07:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "!"
    }
    Add-Content $ConfigFile "!"

    #create zoneset
    Add-Content $ConfigFile "zoneset name ZONESET_VSAN_435 vsan 435"

    #add zones to zoneset 
    $WWPNTableFabA.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("member " + $($_.key))
    }

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "zoneset activate name ZONESET_VSAN_435 vsan 435"

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "!Fabric B Configuration"

    Add-Content $ConfigFile "device-alias database"
    $WWPNTableFabB.GetEnumerator() | Sort-Object Name | % {  
        #Write-Host "Current hashtable is: $($_.key)"
        #Write-Host "Value of Entry 1 is: $($_.value)" 
        $configLine = ("device-alias name " + $($_.key) + " pwwn " + $($_.value))
        Add-Content $ConfigFile $configLine
    }
    Add-Content $ConfigFile "device-alias commit"

    Add-Content $ConfigFile "!"
    
    #create zones 
    $WWPNTableFabB.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("zone name " + $($_.key) + " vsan 436")
        Add-Content $ConfigFile ("member pwwn " + $($_.value))
        Add-Content $ConfigFile "member pwwn 20:00:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:02:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:04:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "member pwwn 20:06:00:a0:98:46:b6:21"
        Add-Content $ConfigFile "!"
    }

    Add-Content $ConfigFile "!"

    #create zoneset
    Add-Content $ConfigFile "zoneset name ZONESET_VSAN_436 vsan 436"

    #add zones to zoneset 
    $WWPNTableFabB.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("member " + $($_.key))
    }

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "zoneset activate name ZONESET_VSAN_436 vsan 436"

    Add-Content $ConfigFile "!"

}
export-modulemember -function Generate-FCSwitchConfig

function Get-BootTargets {

}
export-modulemember -function Get-BootTargets

function Show-Calendar {
#This is an example of a function with arguments
    param(
        [DateTime] $start = [DateTime]::Today,
        [DateTime] $end = $start,
        $firstDayOfWeek,
        [int[]] $highlightDay,
        [string[]] $highlightDate = [DateTime]::Today.ToString()
        )


}
#export-modulemember -function Show-Calendar

Write-Host "Loaded util_netapp.psm1"