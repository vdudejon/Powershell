# A collection of ABX Actions for vRA

## Binpack.ps1
Finds an avaiable ESXi host in a couchdb database, then marks it as reserved and overrides vRA selection with that ESXi host

## Un-Binpack.ps1
Based on vRA destoy VM action, finds the ESXi host assigned to the VM and marks it as free.  Also sets an end time for the VM in the billing database
