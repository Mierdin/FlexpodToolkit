
#Create igroups and LUNs
function createIGroupsAndLuns() {
    
#Reaches into a Cisco UCS Instance, and iterates through every service profile, creating Netapp initiator groups
#for each one, and then putting each service profile's vHBA's WWPNs in the respective initiator groups.

    #We only want Service Profile Instances, not Templates
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


#Generate FC switch config
function generateFCSwitchConfig() {

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
    $WWPNTableFabA.GetEnumerator() | % { 
        #Write-Host "Current hashtable is: $($_.key)"
        #Write-Host "Value of Entry 1 is: $($_.value)" 
        $configLine = "device-alias name " + $($_.key) + " pwwn " + $($_.value)
        Add-Content $ConfigFile $configLine
    }
    Add-Content $ConfigFile "device-alias commit"

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "!Fabric A Configuration"

    Add-Content $ConfigFile "device-alias database"
    $WWPNTableFabB.GetEnumerator() | % { 
        #Write-Host "Current hashtable is: $($_.key)"
        #Write-Host "Value of Entry 1 is: $($_.value)" 
        $configLine = "device-alias name " + $($_.key) + " pwwn " + $($_.value)
        Add-Content $ConfigFile $configLine
    }
    Add-Content $ConfigFile "device-alias commit"
}