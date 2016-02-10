# Author: Thomas Holbrook  - Tom@Jigsaw24.com  http://www.jigsaw24.com
# Date: 28/07/2014

# Comments: 
# This script configures a basic install of AUSST into the "Default Web Site" by default.
# set-executionpolicy unrestricted must be set on the server before running this script, although the script does check prior to running.
# Assumes a brand new install onto Windows Server 2012 R2 and that the server will be a dedicated AUSST Server. 

# Internal Use Only, test prior to deployment on production servers.

# +------------+-----+---------------------------------------------------------+
# |       Date | User| Description                                             |
# +------------+-----+---------------------------------------------------------+
# | 28/07/14   | TJH | Initial Script                                          |
# +------------+-----+---------------------------------------------------------+

# +----------------------------------------------------------------------------+
# | To Do                                                                      |
# +----------------------------------------------------------------------------+                                           |
# | Create a new site rather than "Default Site"                               |
# | Add in some extra logging & error checking.                                |
# | Complete Report Mode                                                       |
# +----------------------------------------------------------------------------+


# ----
# Execution Policy check
# ----

$Policy = "Unrestricted"

If ((get-ExecutionPolicy) -ne $Policy) {
  Write-Host "Setting up execution policy" -backgroundcolor green -foregroundcolor white    
  Set-ExecutionPolicy $Policy -Force
  Write-Host "Relaunch this script" -backgroundcolor green -foregroundcolor white    
  Exit
}

# ----
# Setup the things we need, Modules, Downloads, variables etc.
# ----

# Server managed module, used to install IIS.

Import-Module ServerManager 

# Download a tested AUSST Tool.

try
    {
    Write-Host "Downloading AdobeUpdateServerSetupTool.exe" -backgroundcolor green -foregroundcolor white 
    Invoke-WebRequest -OutFile C:\AdobeUpdateServerSetupTool.exe "https://jss.demo.jigsaw24.com/AdobeUpdateServerSetupTool.exe"
    }
catch
    {
    Write-Host "AdobeUpdateServerSetupTool download failed" -backgroundcolor red -foregroundcolor white
    }

# Get the current hostname.

$hostName=(Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

# Various Paths.

$InetPubRoot = "C:\Inetpub"
$InetPubLog = "C:\Inetpub\Log"
$InetPubWWWRoot = "C:\Inetpub\WWWRoot"
$InetPubWWWAdobe = "C:\Inetpub\WWWRoot\Adobe"
$InetPubWWWAdobeCS = "C:\Inetpub\WWWRoot\Adobe\CS"
$InetPubWWWAdobeCSConfig = "C:\Inetpub\WWWRoot\Adobe\CS\config"
$InetPubWWWAdobeConfig = "C:\Inetpub\WWWRoot\Adobe\CS\config\AdobeUpdaterClient"

# AUSST tool options, used for the Scheduled Tasks.

$setup="C:\AdobeUpdateServerSetupTool.exe"
$setupoptions = "--root=$InetPubWWWAdobeCS --fresh --silent"
$updateoptions = "--root=$InetPubWWWAdobeCS --incremental"
$clientoptions = '--genclientconf="' + $InetPubWWWAdobeConfig + '" --root="' + $InetPubWWWAdobeCS + '" --url="http://' + $hostname + ':80/Adobe/CS"'

# ----
# Create our IIS folder structure
# ----

Function createFolder([STRING]$Path)
    {

$exists = Test-Path $Path -pathType container
             
        if ($exists -eq $false) 
        {
        Write-Host "We are going to try and create the folder..." $Path -backgroundcolor green -foregroundcolor white  
          try
            {
            New-Item -Path $Path -type directory -Force
            }
          Catch
            {
            Write-Host "Folder creation failed" $Path -backgroundcolor red -foregroundcolor white
            }
        }
        else
        {
        Write-Host "Just reporting this folder exists..." $Path -backgroundcolor green -foregroundcolor white    
        }
    }

createFolder $InetPubRoot
createFolder $InetPubLog
createFolder $InetPubWWWRoot
createFolder $InetPubWWWAdobe
createFolder $InetPubWWWAdobeCS
createfolder $InetPubWWWAdobeCSConfig

# ----
# Install IIS 
# ----

Write-Host "Installing IIS" -backgroundcolor green -foregroundcolor white 
try
    {
    Add-WindowsFeature -Name web-server, web-mgmt-console, Web-ISAPI-Ext, Web-ISAPI-Filter
    }
catch
    {
    Write-Host "IIS Install failed." -backgroundcolor red -foregroundcolor white
    }

# ----
# Now we can load the Web Modules
# ----

Import-Module WebAdministration

# ----
# Setup IIS
# ----

# Setup App Pool Manager Pipeline mode to Classic

Set-ItemProperty 'IIS:\Sites\Default Web Site' -name physicalPath -value $InetPubWWWRoot

$appPool = Get-Item IIS:\AppPools\DefaultAppPool
$appPool.managedPipelineMode = "Classic"
$appPool | Set-Item

# Setup Module Mappings, httpHandlers and MIME types.

$unlockCommand = "$env:WINDIR\system32\inetsrv\appcmd.exe"
$unlockOptions = "unlock config -section:system.webServer/handlers"

Invoke-Expression -Command "$unlockCommand $unlockOptions"

New-WebHandler -Name "AdobeXML" -Path "*.xml" -Verb 'GET,POST' -Modules IsapiModule -ScriptProcessor "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll" -PSPath "IIS:\sites\Default Web Site"
New-WebHandler -Name "AdobeCRL" -Path "*.crl" -Verb 'GET,POST' -Modules IsapiModule -ScriptProcessor "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll" -PSPath "IIS:\sites\Default Web Site"
New-WebHandler -Name "AdobeZIP" -Path "*.zip" -Verb 'GET,POST' -Modules IsapiModule -ScriptProcessor "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll" -PSPath "IIS:\sites\Default Web Site"
New-WebHandler -Name "AdobeDMG" -Path "*.dmg" -Verb 'GET,POST' -Modules IsapiModule -ScriptProcessor "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll" -PSPath "IIS:\sites\Default Web Site"
New-WebHandler -Name "AdobeSIG" -Path "*.sig" -Verb 'GET,POST' -Modules IsapiModule -ScriptProcessor "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll" -PSPath "IIS:\sites\Default Web Site"

Add-WebConfiguration /system.web/httpHandlers "IIS:\sites\Default Web Site" -AtIndex 3 -Value @{path="*.xml";verb="*";type="System.Web.StaticFileHandler";validate="true"}
Add-WebConfiguration /system.web/httpHandlers "IIS:\sites\Default Web Site" -AtIndex 4 -Value @{path="*.zip";verb="*";type="System.Web.StaticFileHandler";validate="true"}
Add-WebConfiguration /system.web/httpHandlers "IIS:\sites\Default Web Site" -AtIndex 5 -Value @{path="*.dmg";verb="*";type="System.Web.StaticFileHandler";validate="true"}
Add-WebConfiguration /system.web/httpHandlers "IIS:\sites\Default Web Site" -AtIndex 6 -Value @{path="*.sig";verb="*";type="System.Web.StaticFileHandler";validate="true"}
Add-WebConfiguration /system.web/httpHandlers "IIS:\sites\Default Web Site" -AtIndex 7 -Value @{path="*.crl";verb="*";type="System.Web.StaticFileHandler";validate="true"}

Add-Webconfigurationproperty //staticContent -name collection -value @{fileExtension='.sig'; mimeType='application/octet-stream'}
Add-Webconfigurationproperty //staticContent -name collection -value @{fileExtension='.dmg'; mimeType='file/download'}

#Allow unspecified ISAPI modules - Thanks to Chris Reynolds. 

set-webconfiguration system.webserver/security/isapiCGIRestriction -value "True"

# ----
# Create the setup tasks and sync tasks.
# ----

# Setup the initial setup task to run in 10 minutes, we can re run this task at a later date as a last resort if we have issues as it will re sync the updates.

$Action = New-ScheduledTaskAction -execute $setup -argument $setupoptions
$Trigger = theNew-ScheduledTaskTrigger -Once -At ((get-date) + (New-TimeSpan -Minutes 10))
Register-ScheduledTask -TaskName AUSST_Setup Adobe -Trigger $Trigger -Action $Action -description "AUSST Setup" -User "NT AUTHORITY\SYSTEM" -RunLevel 1      
Set-ScheduledTask AUSST_Setup Adobe -Trigger $Trigger

# Setup the ongoing sync task.

$Action = New-ScheduledTaskAction -execute $setup -argument $updateoptions
$Trigger = New-ScheduledTaskTrigger -Once -At 23:59PM 
Register-ScheduledTask -TaskName AUSST_Update Adobe -Trigger $Trigger -Action $Action -description "AUSST Update" -User "NT AUTHORITY\SYSTEM" -RunLevel 1      
$Trigger.RepetitionInterval = (New-TimeSpan -Days 1)
$Trigger.RepetitionDuration = (New-TimeSpan -Days 1)
Set-ScheduledTask AUSST_Update Adobe -Trigger $Trigger

# Setup Client Config Generation, this has to be ran once the server has downloaded the updates, recommend 24Hours.

$Action = New-ScheduledTaskAction -execute $setup -argument $clientoptions
$Trigger = New-ScheduledTaskTrigger -Once -At ((get-date) + (New-TimeSpan -Days 2))
Register-ScheduledTask -TaskName AUSST_Client Adobe -Trigger $Trigger -Action $Action -description "AUSST Client Config" -User "NT AUTHORITY\SYSTEM" -RunLevel 1      
Set-ScheduledTask AUSST_client Adobe -Trigger $Trigger

# Restart IIS

invoke-command -scriptblock {iisreset}

# All done, this could take a while to sync.

Write-Host "All Done - DotP" $Path -backgroundcolor green -foregroundcolor white    
