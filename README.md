# test-task
I have created Terraform setup for deploying 2 VMs in different av zones with one loadbalancer for them.
Setup includes NAT and LB rules for WinRM and RDP. 
I could not enable WinRM for performing remote management for unknown reason.
I have tried a lot of ways to perform this
Some of them:
azurerm_windows_virtual_machine - connection
azurerm_windows_virtual_machine - winrm and secret blocks
azurerm_virtual_machine - connection and a lot of blocks for configuring rm on the target machine
ansible script for configuring rm
The potential problem is with connection VM to the Internet, VM can not ping and be pinged, but RDP works, firewall and security rules disabled <3

Also I have written script for deploying IIS on the server remotely, it should work
