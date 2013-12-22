

function Set-UcsFirmware {

# UCSM Firmware Update

# Taken from https://communities.cisco.com/docs/DOC-36062
# NOT recommended for production use

#EXAMPLE
# UCSMFirmwareUpdate <version> <ucs> <imageDir> 

    param(
        [parameter(Mandatory=${true})][string]${version},
        [parameter(Mandatory=${true})][string]${ucs},
        [parameter(Mandatory=${true})][string]${imageDir}
    )

    if ((Get-Module | where {$_.Name -ilike "CiscoUcsPS"}).Name -ine "CiscoUcsPS")
	    {
		    Write-Host "Loading Module: Cisco UCS PowerTool Module"
		    Write-Host ""
		    Import-Module CiscoUcsPs
	    }  

    function Start-Countdown{

	    Param(
		    [INT]$Seconds = (Read-Host "Enter seconds to countdown from")
	    )

	    while ($seconds -ge 1){
	        Write-Progress -Activity "Sleep Timer Countdown" -SecondsRemaining $Seconds -Status "Time Remaining"
	        Start-Sleep -Seconds 1
	    $Seconds --
	    }
    }


    function Check-UcsState {

	    $Error.Clear()
	    $output = Get-UcsStatus -ErrorAction SilentlyContinue
	
	    if (${Error}) 
	    {
		    Write-Host "ERROR: Lost UCS connection to UCS Manager Domain: '$($ucs)'"
		    Write-Host "     Error equals: ${Error}"
		    Write-Host ""
		    $output = Disconnect-Ucs -ErrorAction SilentlyContinue
   	        $Error.Clear()
		
		    Write-Host  "RETRY: Retrying login to UCS Manager Domain: '$($ucs)' ..."
		    ${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred} -ErrorAction SilentlyContinue
		    if (${Error}) 
		    {
			    Write-Host "Error creating a session to UCS Manager Domain: '$($ucs)'"
			    Write-Host "     Error equals: ${Error}"
			    Write-Host "     Sleeping for 60 seconds ..."
			    Write-Host ""
	            start-countdown -seconds 60
            }
        }
    }

    # Script only supports one UCS Domain update at a time
    $output = Set-UcsPowerToolConfiguration -SupportMultipleDefaultUcs $false

    Try
    {
        ${Error}.Clear()
   
        ${versionSplit} = ${version}.Split("()")
        ${versionBundle} = ${versionSplit}[0] + "." + ${versionSplit}[1]
    
        ${aSeriesBundle} = "ucs-k9-bundle-infra." + ${versionBundle} + ".A.bin"
        ${bSeriesBundle} = "ucs-k9-bundle-b-series." + ${versionBundle} + ".B.bin"
        ${cSeriesBundle} = "ucs-k9-bundle-c-series." + ${versionBundle} + ".C.bin"
    
	    ${bundle} = @()
        ${bundle} = @(${aSeriesBundle},${bSeriesBundle},${cSeriesBundle})
        ${ccoImageList} = @()
    
	    Write-Host "Starting Firmware download process to local directory: ${imageDir}"
	    Write-Host ""
	
        foreach(${eachBundle} in ${bundle})
        {
            ${fileName} = ${imagedir} +  "\" + ${eachBundle}
             if( test-path -Path ${fileName})
             {
                  Write-Host "Image File : '${eachBundle}' already exist in local directory: '${imageDir}'"
             }
             else
             {
                  ${ccoImageList} += ${eachBundle}
             }
        }
    
        if( ${ccoImageList} -ne ${null})
        {
            Write-Host  "Enter Cisco.com (CCO) Credentials"
            ${ccoCred} = Get-Credential
            foreach(${eachbundle} in ${ccoImageList})
            {
                [array]${ccoImage} += Get-UcsCcoImageList -Credential ${ccoCred} | where { $_.ImageName -match ${eachbundle}}
			    Write-Host "Preparing to download UCS Manager version '$($version)' bundle file: '$($eachbundle)'"
            }
            Write-Host  "Downloading UCS Manager version: '$($version)' bundles to local directory: $($imageDir)"
		    $output = ${ccoImage} | Get-UcsCcoImage -Path ${imageDir}
        }
	    Write-Host "Firmware download process completed to local directory: ${imageDir}"
	    Write-Host ""

	    # Login into UCS
	    Write-Host  "Enter UCS Credentials of UCS Manager to be upgraded to version: '$($version)'"
	    ${ucsCred} = Get-Credential
	    Write-Host ""
	
	    Write-Host "Logging into UCS Domain: '$($ucs)'"
	    Write-Host ""  
        ${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred} -ErrorAction SilentlyContinue
    
	    if (${Error}) 
	    {
		    Write-Host "Error creating a session to UCS Manager Domain: '$($ucs)'"
		    Write-Host "     Error equals: ${Error}"
		    Write-Host "     Exiting"
            exit
        }	
		
        foreach (${image} in ${bundle})
        {
		    Write-Host "Checking if image file: '$($image)' is already uploaded to UCS Domain: '$($ucs)'"
		    ${firmwarePackage} = Get-UcsFirmwarePackage -Name ${image}
            ${deleted} = $false
            if (${firmwarePackage})
            {
           	    # Check if all the images within the package are present by looking at presence
                ${deleted} = ${firmwarePackage} | Get-UcsFirmwareDistImage | ? { $_.ImageDeleted -ne ""}
            }
    
		    if (${deleted} -or !${firmwarePackage})
            {
                # If Image does not exist on FI, uplaod
                $fileName = ${imageDir} +  "\" + ${image}
			    Write-Host "Uploading image file: '$($image)' to UCS Domain: '$($ucs)'"
                $output = Send-UcsFirmware -LiteralPath $fileName | Watch-Ucs -Property TransferState -SuccessValue downloaded -PollSec 30 -TimeoutSec 600
        	    Write-Host "Upload of image file: '$($image)' to UCS Domain: '$($ucs)' completed"
			    Write-Host ""  
		    }
		    else
		    {
			    Write-Host "Image file: '$($image)' is already uploaded to UCS Domain: '$($ucs)'"
			    Write-Host ""  
		    }
        }
          
        # Convert version to avoid cannot validate argument on parameter 'Name'. Ex 1.4(3i) should be 1.4-3i
        [array]${versionName} = ${version}.Split("()")
        ${versionPack} = ${versionName}[0] + "-" + ${versionName}[1]
            
        ${bSeriesVersion} = ${version} + "B"
        ${cSeriesVersion} = ${version} + "C"
        [array]${imageNames} = (Get-UcsFirmwarePackage | ? { $_.Version -like ${bSeriesVersion} -or $_.Version -like ${cSeriesVersion} } | Get-UcsFirmwareDistImage | select -ExpandProperty Name)
        [array]${images} = (Get-UcsFirmwareInstallable | ? { $_.Model -ne "MGMTEXT" -and $_.Model -ne "CAPCATALOG" -and ${imageNames} -contains $_.Name })

	    # Check if host-pack (with the version as name) exist
        if (Get-UcsFirmwareComputeHostPack -Name ${versionPack})
        {
            Write-Host "Host Firmware pack: '$($versionPack)' already exists on UCS Domain: '$($ucs)'"
        }
        else # Create a host-pack
        {
            Write-Host "Creating Host Firmware pack: '$($versionPack)' on UCS Domain: '$($ucs)'"
            $output = Start-UcsTransaction
            ${firmwareComputeHostPack} = Add-UcsFirmwareComputeHostPack -Name ${versionPack} -ModifyPresent
            $output = ${images} | ? { $_.Type -ne "blade-controller" -and $_.Type -ne "CIMC" } | % { ${firmwareComputeHostPack} | Add-UcsFirmwarePackItem -HwModel $_.Model -HwVendor $_.Vendor -Type $_.Type -Version $_.Version -ModifyPresent}
            $output = Complete-UcsTransaction
        }
    
	    Write-Host ""
		  
        # Check if mgmt-pack (with the version as name) exist
        if (Get-UcsFirmwareComputeMgmtPack -Name ${versionPack})
        {
            Write-Host "Management Firmware pack: '$($versionPack)' already exists on UCS Domain: '$($ucs)'"
        }
        else # Create a mgmt-pack
        {
            Write-Host "Creating Management Firmware pack: '$($versionPack)' on UCS Domain: '$($ucs)'"
            $output = Start-UcsTransaction
            ${firmwareComputeMgmtPack} = Add-UcsFirmwareComputeMgmtPack -Name ${versionPack} -ModifyPresent
            $output = ${images} | ? { $_.Type -eq "blade-controller" -or $_.Type -eq "CIMC" } | % { ${firmwareComputeMgmtPack} | Add-UcsFirmwarePackItem -HwModel $_.Model -HwVendor $_.Vendor -Type $_.Type -Version $_.Version -ModifyPresent }
            $output = Complete-UcsTransaction
        }

	    Write-Host ""
        # Activate UCSM
        ${firmwareRunningUcsm} = Get-UcsMgmtController -Subject system | Get-UcsFirmwareRunning
        if (${firmwareRunningUcsm}.version -eq ${version})
        {
            Write-Host "UCS Manager 'running' software version already at version: '${version}' on UCS Domain: '$($ucs)'"
        }
        else
        {
            Write-Host "Activating UCS Manager software to version: '${version}' on UCS Domain: '$($ucs)'"
		    Write-Host "     Requires a re-login to UCS Manager after UCS Manager Upgrade"
            $output = Get-UcsMgmtController -Subject system | Get-UcsFirmwareBootDefinition | Get-UcsFirmwareBootUnit | Set-UcsFirmwareBootUnit -Version ${version} -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes -Force
            Write-Host "Please wait while UCS Manager restarts on UCS Domain: '$($ucs)'"
		    Write-host "     Operation may take 3 or more minutes"
            Try
            {
    		    Write-Host "Disconnecting session from UCS Manager Domain: '$($ucs)'"
			    $output = Disconnect-Ucs
            }
            Catch
            {
               Write-Host "Error disconnecting session from UCS Manager Domain: '$($ucs)'"
            }
            Write-Host "Sleeping for 3 minutes ..."
		    Write-Host ""  
            start-countdown -seconds 180
		    ${count} = 0
		    do
            {
			    ${count}++
			    $Error.Clear()
			    Write-Host  "Attempt ${count}: Retrying login to UCS Manager Domain: '$($ucs)' ..."
		        ${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred} -ErrorAction SilentlyContinue
            
			    if (${Error}) 
			    {
				    Write-Host "Error creating a session to UCS Manager Domain: '$($ucs)'"
				    Write-Host "     Error equals: ${Error}"
				    Write-Host "     Sleeping for 60 seconds ..."
				    Write-Host ""
		            start-countdown -seconds 60
                }
            } while (${myCon} -eq ${null})
	
		    Write-Host "Successfully logged back into UCS Domain: '${ucs}'"
	
		    ${firmwareRunningUcsm} = Get-UcsMgmtController -Subject system | Get-UcsFirmwareRunning
    	    if (${firmwareRunningUcsm}.version -eq ${version})
    	    {
        	    Write-Host "UCS Manager 'running' software version updated to version: '${version}' successfully on UCS Domain: '$($ucs)'"
    	    } 
		    else
		    {
			    Write-Host "UCS Manager 'running' software version 'NOT' updated to version: '${version}' successfully on UCS Domain: '$($ucs)'"
			    Write-Host "Exiting"
			    exit
		    }
        }

	    Write-Host ""
	    # Update/Activate IOM
        Write-Host "Upgrading IO Module(s) Firmware to version: '$($version)' on UCS Domain: '$($ucs)'"
	    ${iomController} = Get-UcsChassis | Get-UcsIom | Get-UcsMgmtController -Subject iocard
        ${iomBackupUpdateList} = @()
	    ${iomStartupUpdateList} = @()

        foreach (${iom} in ${iomController})
        {
            ${firmwareRunning} = ${iom} | Get-UcsFirmwareRunning -Deployment system
		    ${firmwareUpdatable} = ${iom} | Get-UcsFirmwareUpdatable 
		    ${iomslot} = ($iom | Get-Ucsparent).Dn
            if (${firmwareRunning}.version -eq ${version})
            {
                Write-Host "IOM: '${iomslot}' running firmware version is already set to version: '${version}' - No update needed"
            }
            else
            {
                Write-Host "IOM: '${iomslot}' running firmware version is: '$($firmwareRunning.Version)'"
			    Write-Host "     IO Module will be updated to version: '${version}'"
                ${iomStartupUpdateList} += ${iom}
            }
		
		    if (${firmwareUpdatable}.version -eq ${version})
            {
                Write-Host "IOM: '${iomslot}' backup firmware version already set to version: '${version}' - No update needed"
            }
            else
            {
                Write-Host "IOM: '${iomslot}' backup firmware version is: '$($firmwareRunning.Version)'"
			    Write-Host "     IO Module will be updated to version: '${version}'"
                ${iomBackupUpdateList} += ${iom}
            }
        }

	    if (${iomBackupUpdateList} -ne $null )
	    {
		    Write-Host "Setting IO Module(s) backup firmware version to: '${version}' on UCS Domain: '$($ucs)' for IO Module(s):"
		    ${iomslotlist} = @()
		    foreach (${iom} in ${iomBackupUpdateList})
		    {
			    ${iomslotlist} += ($iom | Get-Ucsparent).Dn
		    }
		    ${iomslotlist} | % {Write-Host $_ }
	        Write-Host ""

		    $output = ${iomBackupUpdateList} |  Get-UcsFirmwareUpdatable | Set-UcsFirmwareUpdatable -Version ${version} -AdminState triggered -Force
	 	    Write-Host "     IO Module backup firmware version update process can take 8 or more minutes."
		    Write-Host "     Sleeping for 8 minutes ..."
		    Write-Host ""
	        start-countdown -seconds 480
		    ${count} = 0
		    do
	        {
			    ${count}++
			
			    Check-UcsState
			
			    Write-Host "Attempt ${count}: Checking IOM progress for updating IOM backup firmware version on UCS Domain: '$($ucs)'..."
			    ${readyCount} = ${iomBackupUpdateList} |  Get-UcsFirmwareUpdatable -OperState ready | measure
	            if (${readyCount}.count -eq ${iomBackupUpdateList}.count)
	            {
	                break
	            }
	            Write-Host "     IO Module backup version update process not completed on UCS Domain: '$($ucs)'"
			    Write-Host "     Sleeping for 60 seconds..."
			    Write-Host ""
			    start-countdown -seconds 60
	        } while (${readyCount}.count -ne ${iomBackupUpdateList}.count)
		    Write-Host ""
		    Write-Host "IO Module backup firmware version update process completed on UCS Domain: '$($ucs)'..."
		    Write-Host ""
	    }

	    if (${iomStartupUpdateList} -ne $null )
	    {
		    Write-Host "Setting IO Module(s) startup firmware version to: '${version}' on UCS Domain: '$($ucs)' for IO Module(s):"
		    ${iomslotlist} = @()
		    foreach (${iom} in ${iomStartupUpdateList})
		    {
			    ${iomslotlist} += ($iom | Get-Ucsparent).Dn
		    }
		    ${iomslotlist} | % {Write-Host $_ }
	        Write-Host ""

		    $output = ${iomStartupUpdateList} | Get-UcsFirmwareBootDefinition | Get-UcsFirmwareBootUnit | Set-UcsFirmwareBootUnit -Version ${version} -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate no -Force | Watch-Ucs -Property OperState -SuccessValue pending-next-boot -PollSec 30 -TimeoutSec 600

		    ${count} = 0
		    do
	        {
			    ${count}++

			    Check-UcsState
			
			    $Error.Clear()			
						
			    Write-Host "Attempt ${count}: Checking progress for updating IOM startup firmware version on UCS Domain: '$($ucs)'..."
			    ${readyCount} = ${iomStartupUpdateList} |  Get-UcsFirmwarebootdefinition | Get-UcsFirmwareBootUnit | ? { $_.operState -ieq "pending-next-boot" -and $_.version -eq "${version}" } | measure
	            if (${readyCount}.count -eq ${iomStartupUpdateList}.count)
	            {
	                break
	            }
	            Write-Host "     IO Module startup version update process not completed on UCS Domain: '$($ucs)'"
			    Write-Host "     Sleeping for 60 seconds..."
			    Write-Host ""
			    start-countdown -seconds 60
	        } while (${readyCount}.count -ne ${iomStartupUpdateList}.count)
		
		    Write-Host "     IO Module startup firmware version update process completed on UCS Domain: '$($ucs)'..."
		    Write-Host ""
	    }
	
	    Write-Host "IO Module firmware update process completed on UCS Domain: '$($ucs)'."
	    Write-Host ""
	
	    Write-Host "Upgrading Fabric Interconnect(s) Firmware to version: '$($version)' on UCS Domain: '$($ucs)'"
        # Check version for Fabric Interconnect update
        ${aSeriesVersion} = ${version} + "A"
        ${switchVersion} = Get-UcsFirmwarePackage -Version ${aSeriesVersion} | Get-UcsFirmwareDistImage | % { Get-UcsFirmwareInstallable -Name $_.Name -Type switch-software }
    
	    # Check for HA configuration of UCS Manager
   
	    if (Get-UcsStatus | ? { $_.HaConfiguration -eq "cluster" })
        {
            # Activate Subordinate FI
		    ${secFI} = Get-UcsNetworkElement -Id (Get-UcsMgmtEntity -Leadership subordinate).Id 
            ${secFiController} = ${secFI} | Get-UcsMgmtController
		    Write-Host "Updating Subordinate Fabric Interconnect: $(${secFi}.Dn) to version: '$(${switchVersion}[0].version)' on UCS Domain: '$($ucs)'"
            ${secFiActivated} = ${secFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes -Force
            # Wait for Subordinate to complete re-boot & check for activate status .. 10 or more minutes
            if(${secFiActivated} -ne ${null})
            {
                Write-Host "     Subordinate Fabric Interconnect firmware update process can take 10 or more minutes."
			    Write-Host "     Sleeping for 10 minutes ..."
			    Write-Host ""
                start-countdown -seconds 600
			    ${count} = 0
                do
                {
			 	    ${count}++
				
				    Check-UcsState

				    $Error.Clear()
				
				    ${readyCount} = ${secFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit |  ?  { $_.OperState -eq "ready" }  | measure
                    if (${readyCount}.count -eq ${secFiActivated}.count)
                    {
                        break
                    }
 				    Write-Host "Attempt ${count}: Subordinate Fabric Interconnect: $(${secFi}.Dn) update process not completed on UCS Domain: '$($ucs)'."
				    Write-Host "     Sleeping for 60 seconds..."
				    Write-Host ""
                    start-countdown -seconds 60
                } while (${readyCount}.count -ne ${secFiActivated}.count)
			    Write-Host "Subordinate Fabric Interconnect: $(${secFi}.Dn) running firmware for version: '$(${switchVersion}[0].version)' is in 'ready' state on UCS Domain: '$($ucs)'."
			    Write-Host ""
			    Write-Host "Checking IO Module(s) connected to Subordinate Fabric Interconnect: $(${secFi}.Dn) are in 'ready' state on UCS Domain: '$($ucs)'..."
			    ${count} = 0
			    $iomUpdateList = @()
			    do
    		    {	
				    ${count}++
				
				    Check-UcsState
				
				    $Error.Clear()
								
				    ${iomUpdateList} = Get-UcsChassis | Get-UcsIom -SwitchId ${secFI}.Id | Get-UcsMgmtController -Subject iocard
				    ${readyCount} = ${iomUpdateList} |  Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit |  ?  { $_.OperState -eq "ready" } | measure
		            if (${readyCount}.count -eq (${iomUpdateList} | measure).count)
		            {
		                break
		            }
		            Write-Host "Attempt ${count}: IO Modules connected to Subordinate Fabric Interconnect: : $(${secFi}.Dn) are 'NOT' in 'ready' state on UCS Domain: '$($ucs)'..."
				    Write-Host "     Sleeping for 60 seconds..."
				    Write-Host ""
				    start-countdown -seconds 60
		        } while (${readyCount}.count -ne (${iomUpdateList} | measure).count)
			    Write-Host ""
			    Write-Host "IO Modules connected to Subordinate Fabric Interconnect: : $(${secFi}.Dn) are now in 'ready' state on UCS Domain: '$($ucs)'...."
			    Write-Host ""
			    Write-Host "Verifying Fabric Interconnect Cluster high availability is in 'ready' state on UCS Domain: '${ucs}'..."
			
			    ${count} = 0
			    ${fiMgmtEntity} = @()
			    do
    		    {	
				    ${count}++
				
				    Check-UcsState
								
				    ${fiMgmtEntity} = Get-UcsMgmtEntity 
				    ${readyCount} = ${fiMgmtEntity} | ? { $_.hareadiness -eq "ready" -and $_.haready -eq "yes" }  | measure
		            if (${readyCount}.count -eq (${fiMgmtEntity} | measure).count)
		            {
		                break
		            }
		            Write-Host "Attempt ${count}: Fabric Interconnect Cluster high availability is 'NOT' in 'ready' state on UCS Domain: '$($ucs)'..."
				    Write-Host "     Sleeping for 60 seconds..."
				    Write-Host ""
				    start-countdown -seconds 60
		        } while (${readyCount}.count -ne (${iomUpdateList} | measure).count)
		        Write-Host "Fabric Interconnect Cluster high availability is now in 'ready' state on UCS Domain: '$($ucs)'..."
			    Write-Host "Subordinate Fabric Interconnect: $(${secFi}.Dn) firmware update process completed on UCS Domain: '$($ucs)'."
    	    }
    	    else
    	    {
            Write-Host "Subordinate Fabric Interconnect: $(${secFi}.Dn) firmware already at version $(${switchVersion}[0].version) on UCS Domain: '$($ucs)' -  No firmware update needed"
    	    }         
		    Write-Host ""
	    
            # Activate primary FI
		    ${priFI} = Get-UcsNetworkElement -Id (Get-UcsMgmtEntity -Leadership primary).Id 
            ${priFiController} = ${priFI} | Get-UcsMgmtController
		    Write-Host "Updating Primary Fabric Interconnect: $(${priFi}.Dn) to version: '$(${switchVersion}[0].version)' on UCS Domain: '$($ucs)'..."
            ${priFiActivated} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes -Force
        }
        else
        {
    	    ${priFI} = Get-UcsNetworkElement
		    ${priFiController} = Get-UcsMgmtController -Subject switch
		    Write-Host "Updating Primary Fabric Interconnect: $(${priFi}.Dn) to version: '$(${switchVersion}[0].version)' on UCS Domain: '$($ucs)'..."
		    ${priFiActivated} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes -Force
        }
    
        if (${priFiActivated} -ne ${null})
        {
            Write-Host "     Primary Fabric Interconnect: $(${priFi}.Dn) firmware update process can take take 15 or more minutes"
            Try
            {
			    Write-Host "     Disconnecting session from UCS Manager Domain: '$($ucs)'"
                $output = Disconnect-Ucs
            }
            Catch
            {
               Write-Host "     Error disconnecting session from UCS Manager Domain: '$($ucs)'"
            }
            Write-Host  "     Sleeping for 15 minutes ..."
		    Write-Host ""
            start-countdown -seconds 900
		    ${count} = 0
            do
            {
			    ${count}++
			    $Error.Clear()
			    Write-Host  "Attempt ${count}: Retrying login to UCS Manager Domain: '$($ucs)' ..."
    		    ${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred} -ErrorAction SilentlyContinue
            
			    if (${Error}) 
			    {
				    Write-Host "Error creating a session to UCS Manager Domain: '$($ucs)'"
				    Write-Host "     Error equals: ${Error}"
				    Write-Host "     Sleeping for 60 seconds ..."
				    Write-Host ""
		            start-countdown -seconds 60
                }
            } while (${myCon} -eq ${null})
		    Write-Host "Successfully logged back into UCS Domain: '${ucs}'"
	    }
 
	    # Check if primary FI activated successfully
	    Write-Host "Checking to see if Primary Fabric Interconnect: $(${priFi}.Dn) firmware update process completed successfully for UCS Domain: '${ucs}'"
	    Write-Host ""
	
        if(${priFiActivated} -ne ${null})
        {
            ${count} = 0
		    do
            {
			    ${count}++
			    $Error.Clear()
			    $output = Get-UcsTopSystem
			
			    if (${Error}) 
			    {
				    Write-Host "Error connecting to UCS session to UCS Manager Domain: '$($ucs)'"
				    Write-Host "     Error equals: ${Error}"
				    Write-Host ""
				    $output = Disconnect-Ucs -ErrorAction SilentlyContinue
		   	        $Error.Clear()
				
				    Write-Host  "Attempt ${count}: Retrying login to UCS Manager Domain: '$($ucs)' ..."
    			    ${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred} -ErrorAction SilentlyContinue
				    if (${Error}) 
				    {
					    Write-Host "Error creating a session to UCS Manager Domain: '$($ucs)'"
					    Write-Host "     Error equals: ${Error}"
					    Write-Host "     Sleeping for 60 seconds ..."
					    Write-Host ""
			            start-countdown -seconds 60
	                }
                }
			    else 
			    {
				    if (Get-UcsStatus | ? { $_.HaConfiguration -eq "cluster" })
	                {
	                    ${priFiController} = Get-UcsNetworkElement -Id ${priFI}.Id | Get-UcsMgmtController
	                }
	                else
	                {
	                    ${priFiController} = Get-UcsMgmtController -Subject switch
	        	    }
	    
				    ${readyCount} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit  |  ?  { $_.OperState -eq "ready" }  | measure
	                if (${readyCount}.count -eq ${priFiActivated}.count)
	                {
	                    break
	                }
	                Write-Host "Attempt ${count}: Primary Fabric Interconnect: $(${secFi}.Dn) update process not completed on UCS Domain: '$($ucs)'."
				    Write-Host "     Sleeping for 60 seconds..."
				    Write-Host ""
	                start-countdown -seconds 60
			    }
		    } while (${readyCount}.count -ne ${priFiActivated}.count)
		    Write-Host "Primary Fabric Interconnect: $(${priFi}.Dn) running firmware for version: '$(${switchVersion}[0].version)' is in 'ready' state on UCS Domain: '$($ucs)'."
		
		    ${count} = 0
		    ${iomUpdateList} = @()
		    do
    	    {
			    ${count}++
			
			    Check-UcsState

			    $Error.Clear()
			
			    Write-Host "Attempt ${count}: Checking IO Module(s) connected to Primary Fabric Interconnect: $(${priFi}.Dn) are in 'ready' state on UCS Domain: '$($ucs)'..."
			    ${iomUpdateList} = Get-UcsChassis | Get-UcsIom -SwitchId $priFI.Id | Get-UcsMgmtController -Subject iocard
			    ${readyCount} = ${iomUpdateList} |  Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit |  ?  { $_.OperState -eq "ready" } | measure
	            if (${readyCount}.count -eq (${iomUpdateList} | measure).count)
	            {
	                break
	            }
	            Write-Host "     IO Modules connected to Primary Fabric Interconnect: : $(${priFi}.Dn) are 'NOT' in 'ready' state on UCS Domain: '$($ucs)'..."
			    Write-Host "     Sleeping for 60 seconds..."
			    Write-Host ""
			    start-countdown -seconds 60
	        } while (${readyCount}.count -ne (${iomUpdateList} | Measure).count)
		    Write-Host ""
		    Write-Host "IO Modules connected to Primary Fabric Interconnect: : $(${priFi}.Dn) are now in 'ready' state on UCS Domain: '$($ucs)'...."
		    Write-Host ""
		    Write-Host "Verifying Fabric Interconnect Cluster high availability is in 'ready' state on UCS Domain: '${ucs}'..."
		
		    ${count} = 0
		    ${fiMgmtEntity} = @()
		    do
		    {	
			    ${count}++
			
			    Check-UcsState
			
			    $Error.Clear()
					
			    ${fiMgmtEntity} = Get-UcsMgmtEntity 
			    ${readyCount} = ${fiMgmtEntity} | ? { $_.hareadiness -eq "ready" -and $_.haready -eq "yes" }  | measure
	            if (${readyCount}.count -eq (${fiMgmtEntity} | measure).count)
	            {
	                break
	            }
	            Write-Host "Attempt ${count}: Fabric Interconnect Cluster high availability is 'NOT' in 'ready' state on UCS Domain: '$($ucs)'..."
			    Write-Host "     Sleeping for 60 seconds..."
			    Write-Host ""
			    start-countdown -seconds 60
	        } while (${readyCount}.count -ne (${iomUpdateList} | measure).count)
		    Write-Host ""
            Write-Host "Fabric Interconnect Cluster high availability is now in 'ready' state on UCS Domain: '$($ucs)'..."
		    Write-Host "Primary Fabric Interconnect: $(${priFi}.Dn) firmware update process completed on UCS Domain: '$($ucs)'"
	    }
        else
        {
            Write-Host "Primary Fabric Interconnect: $(${priFi}.Dn) firmware already at version $(${switchVersion}[0].version) on UCS Domain: '$($ucs)' -  No firmware update needed"
        }
    
	    Write-Host "Fabric Interconnect firmware update process completed on UCS Domain: '$($ucs)'."    
	    Write-Host ""
    
	    Write-Host "Updating all service profile updating templates to use Host and Management Firmware pack version: '${version} on UCS Domain: '$($ucs)'."    
        # Update host & management pack name for all updating-template service profiles
        $output = Get-UcsServiceProfile -Type updating-template | ? { $_.HostFwPolicyName -ne ${versionPack} -or $_.MgmtFwPolicyName -ne ${versionPack} } | Set-UcsServiceProfile -HostFwPolicyName ${versionPack} -MgmtFwPolicyName ${versionPack} -Force
    
	    Write-Host "Updating all service profile instances to use Host and Management Firmware pack version: '${version} on UCS Domain: '$($ucs)'."  
	    Write-Host ""
	    # Update host & management pack name for all instance and initial-template service profiles
        $output = Get-UcsServiceProfile | ? { $_.Type -ne "updating-template" } | ? { $_.HostFwPolicyName -ne ${versionPack} -or $_.MgmtFwPolicyName -ne ${versionPack} } | Set-UcsServiceProfile -HostFwPolicyName ${versionPack} -MgmtFwPolicyName ${versionPack} -Force
        #Disconnect from UCS
        Write-Host "Install-All update update process to version: ${version} executed successfully"
	    Write-Host "     Disconnecting from UCS Domain: '${ucs}'"
        $output = Disconnect-Ucs
    }
    Catch
    {
	     Write-Host "Error occurred in script:"
         Write-Host ${Error}
         exit
    }
}
export-modulemember -function Set-UcsFirmware

Write-Host "Loaded util_ucs.psm1"