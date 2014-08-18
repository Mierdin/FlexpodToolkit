<#
 Name:         Flexpod Toolkit
 Author:       Matthew Oswalt
 Created:      8/17/2014
 Description:  This script contains all buildout functions for Netapp
               For more information, and an exhaustive, updated list of dependencies, see https://github.com/Mierdin/FlexpodToolkit

#>


<#
.SYNOPSIS
Creates a new vServer

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
function Create-vServer {

    param(
        [parameter(Mandatory=${true})][string[]]$FabAWWPNs,
        [parameter(Mandatory=${true})][string[]]$FabBWWPNs,
        [parameter(Mandatory=${false})][string]$SPfilter
    )

    $newVServer = New-NcVserver -Name $NAvserver -RootVolume $NAvserverRootVol -RootVolumeAggregate "aggr1_DCB6250_02_SATA" -RootVolumeSecurityStyle UNIX -NameServerSwitch nis
    Set-NcVserver -Name $NAvserver -DisallowedProtocols iscsi #,nfs

}
export-modulemember -function Create-vServer