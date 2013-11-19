<# 
 .Synopsis
  Allows a PowerShell script to simply and quickly automate Netapp-related tasks within a Flexpod.

 .Description
  Displays a visual representation of a calendar. This function supports multiple months
  and lets you highlight specific date ranges or days.

 .Parameter Start
  The first month to display.

 .Parameter End
  The last month to display.

 .Parameter FirstDayOfWeek
  The day of the month on which the week begins.

 .Parameter HighlightDay
  Specific days (numbered) to highlight. Used for date ranges like (25..31).
  Date ranges are specified by the Windows PowerShell range syntax. These dates are
  enclosed in square brackets.

 .Parameter HighlightDate
  Specific days (named) to highlight. These dates are surrounded by asterisks.
  

 .Example
   # Show a default display of this month.
   Show-Calendar

 .Example
   # Display a date range.
   Show-Calendar -Start "March, 2010" -End "May, 2010"

 .Example
   # Highlight a range of days.
   Show-Calendar -HighlightDay (1..10 + 22) -HighlightDate "December 25, 2008"
#>


#Create igroups and LUNs
function Create-IGroupsAndLuns {
    
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
export-modulemember -function Create-IGroupsAndLuns


#Generate FC switch config
function Generate-FCSwitchConfig {

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
        Add-Content $ConfigFile ("zone name " + $($_.key) + " vsan 235")
        Add-Content $ConfigFile ("member pwwn " + $($_.value))
        #Need to add an argument to this function that pulls the four values from the UCS boot policy and uses them
        Add-Content $ConfigFile "member pwwn 20:09:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:0b:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:0d:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:0f:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "!"
    }
    Add-Content $ConfigFile "!"

    #create zoneset
    Add-Content $ConfigFile "zoneset name ZONESET_VSAN_235 vsan 235"

    #add zones to zoneset 
    $WWPNTableFabA.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("member " + $($_.key))
    }

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "zoneset activate name ZONESET_VSAN_235 vsan 235"

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
        Add-Content $ConfigFile ("zone name " + $($_.key) + " vsan 236")
        Add-Content $ConfigFile ("member pwwn " + $($_.value))
        #Need to add an argument to this function that pulls the four values from the UCS boot policy and uses them
        Add-Content $ConfigFile "member pwwn 20:0a:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:0c:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:0e:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "member pwwn 20:10:00:a0:98:46:b8:21"
        Add-Content $ConfigFile "!"
    }

    Add-Content $ConfigFile "!"

    #create zoneset
    Add-Content $ConfigFile "zoneset name ZONESET_VSAN_236 vsan 236"

    #add zones to zoneset 
    $WWPNTableFabB.GetEnumerator() | Sort-Object Name | % { 
        Add-Content $ConfigFile ("member " + $($_.key))
    }

    Add-Content $ConfigFile "!"

    Add-Content $ConfigFile "zoneset activate name ZONESET_VSAN_236 vsan 236"

    Add-Content $ConfigFile "!"

}
export-modulemember -function Generate-FCSwitchConfig

function Show-Calendar {
    param(
        [DateTime] $start = [DateTime]::Today,
        [DateTime] $end = $start,
        $firstDayOfWeek,
        [int[]] $highlightDay,
        [string[]] $highlightDate = [DateTime]::Today.ToString()
        )


}
#export-modulemember -function Show-Calendar