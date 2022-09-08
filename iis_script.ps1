Start-Service -Name Winrm
$server = Read-Host "Enter the server's IP-address"
$port = Read-Host "Enter the server's connection port"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$server" -Force
$session = New-PSSession -ComputerName "$server" -Credential $(Get-Credential) -Port "$port"


$DeployScript = {

Add-WindowsFeature Web-Scripting-Tools
Import-Module WebAdministration
Get-WebBinding -Port 80 -Name "TestSite" | Remove-WebBinding
if ((Test-Path "IIS:\Sites\Webserver") -eq $True) {
    Remove-WebSite -Name "Webserver" }

if ((Test-Path "IIS:\AppPools\Webserver-AppPool") -eq $True) {
    Remove-WebAppPool -Name "Webserver-AppPool" }

if ((Test-Path "$env:systemdrive\Sites\Webserver") -eq $True) {
    Remove-Item "$env:systemdrive\Sites\Webserver" -Recurse }

New-Item -ItemType directory -Path "$env:systemdrive\Sites\Webserver"
New-Website -Name "Webserver" -Port 80 -IPAddress "*" -HostHeader "" -PhysicalPath "$env:systemdrive\Sites\Webserver"
New-Item -Path "IIS:\AppPools" -Name "Webserver-AppPool" -Type AppPool
Set-ItemProperty -Path "IIS:\Sites\Webserver" -name "applicationPool" -value "Webserver-AppPool"
New-Item -Path "$env:systemdrive\Sites\Webserver" -Name "Default.html" -ItemType "file" -Value "Hello! This is the test page of Webserver."
Start-Website -Name "Webserver"

}


Invoke-Command -Session $session -ScriptBlock $DeployScript
Remove-PSSession -Session $session
