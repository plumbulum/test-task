

# Starting WinRM Service on local machine
Start-Service -Name Winrm

# Entering the server's IP-address or DNS-name to connect with
$server = Read-Host "Enter the server's IP-address"

$port = Read-Host "Enter the server's connection port"
# Setting the entered server as a trusted host
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$server" -Force

# Creating a connection(session) to a remote computer
$session = New-PSSession -ComputerName "$server" -Credential $(Get-Credential) -Port "$port"

$DeployScript = {

# Script to deploy a website on IIS Server
Add-WindowsFeature Web-Scripting-Tools

Import-Module WebAdministration

# Unbinding a port "80" from the Default IIS Web Site
Get-WebBinding -Port 80 -Name "TestSite" | Remove-WebBinding

# Checking the existence of such website, application pool and site folder, and remove them if exist
if ((Test-Path "IIS:\Sites\Webserver") -eq $True) {
    Remove-WebSite -Name "Webserver"
}

if ((Test-Path "IIS:\AppPools\Webserver-AppPool") -eq $True) {
    Remove-WebAppPool -Name "Webserver-AppPool"
}

if ((Test-Path "$env:systemdrive\Sites\Webserver") -eq $True) {
    Remove-Item "$env:systemdrive\Sites\Webserver" -Recurse
}

# Creating a site folder for a new WebSite
New-Item -ItemType directory -Path "$env:systemdrive\Sites\Webserver"

# Creating a new WebSite
New-Website -Name "Webserver" -Port 80 -IPAddress "*" -HostHeader "" -PhysicalPath "$env:systemdrive\Sites\Webserver"

# Creating an Application Pool and associate it with the created WebSite
New-Item -Path "IIS:\AppPools" -Name "Webserver-AppPool" -Type AppPool

Set-ItemProperty -Path "IIS:\Sites\Webserver" -name "applicationPool" -value "Webserver-AppPool"

# Creating a simple test web-page
New-Item -Path "$env:systemdrive\Sites\Webserver" -Name "Default.html" -ItemType "file" -Value "Hello! This is the test page of Webserver."

# Starting WebSite
Start-Website -Name "Webserver"

}

# Running a ps-script on a remote computer
Invoke-Command -Session $session -ScriptBlock $DeployScript

# Removing the connection(session)
Remove-PSSession -Session $session