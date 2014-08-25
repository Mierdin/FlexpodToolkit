# ABOUT

A suite of scripts aimed at automating nearly every aspect of the provisioning process in a Flexpod environment. 

Due to the relatively predictable nature of a pod-based reference architecture like Flexpod, this suite is built on the premise of reducing unnecessary redundancy in user input. Wherever possible, these scripts derive configuration information from the infrastructure itself.

The modules are named according to use case. However, any function in any module can reach into any part of a flexpod for both configuring and retrieving information. 
For example, the function that creates boot LUNs works by first looking at the service profiles in UCS. 
In summary, the module named CiscoUCS doesn't necessarily just reach into Cisco UCS.

# STATUS

This project will likely soon come to a halt. I have been considering moving these functions to Python, and I am working on making those ideas real in my new project, [PyFlex](https://github.com/Mierdin/pyflex)

This project is still my go-to for building new Flexpod Configurations, as I know it works, and I haven't gotten PyFlex up to the quality I need it to be at yet, but it is the direction I want to go. So for now, enjoy these scripts, and keep an eye out for PyFlex.

# SUPPORTED PRODUCTS

- NetApp Release 8.2P2 Cluster-Mode
- Cisco UCSM 2.1(3a)
- Nexus 5596UP running 6.0(2)N2(2)
- VMWare vSphere 5.5

# DEPENDENCIES

- Powershell 3.0 or above **REQUIRED**
- PowerCLI 5.5.0
- Cisco PowerTool 1.0.0.0
- Netapp PowerShell Toolkit 3.0.0.90

Powershell, Cisco UCS, Netapp Cluster mode, Cisco 5596UP switches.
Will update with tested platforms and code releases

# CONTRIBUTORS

Matt Oswalt, @Mierdin
