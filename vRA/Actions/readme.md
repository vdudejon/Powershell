# A collection of ABX Actions for vRA

## Binpack.ps1
Finds an avaiable ESXi host in a couchdb database, then marks it as reserved and overrides vRA selection with that ESXi host

## HPCify.ps1
At the end of a vRA deployment, find all VMs in the deployment and configure their virtual hardware for HPC purposes
- Set 100% CPU and Memory Reservations
- Set CPUs per Core as cores / sub-numa nodes
- Set Latency Sensitivity to High
- Configure the HPC nic for SR-IOV
- Add and pass through any GPUs

## Un-Binpack.ps1
Based on vRA destoy VM action, finds the ESXi host assigned to the VM and marks it as free.  Also sets an end time for the VM in the billing database
 
## Set-Billing.ps1
Set a start time for the VM in the billing database

## Set-VMName.ps1
Create names for VMs that look neat and are in order, for example hpc001-hpc005
