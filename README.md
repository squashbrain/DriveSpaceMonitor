![Pushover Icon](/Icons/DrivePic_64x64.png) 
# DriveSpaceMonitorService
Drive Space Monitoring Tool + Pushover Notifications

This DriveSpaceMonitor is a Windows service which will monitor Drive space on one or more drives.  
In the event that the free drive space remaining reaches a preset trigger point, it will send a 
Pushover alert to a technician to handle the problem.

## Motivation
I manage AWS servers for production as part of my job and one of the drives filled up before me or anyone else noticed it.  I searched all over for a Windows Service that could monitor multiple drives and send Pushover notifications.  I couldnt find one so I decided to build one.  There are plenty of great drive space monitors built on the .NET platform written in C# but we preferred to use a non .NET platform.

## Source
The project was created with Delphi XE7 but It should be compatible from Delphi 2010 and up.<br>
*Requires Indy version 10.60 or greater which uses the OpenSSL libraries*

## Binaries
Prefer not to build the source or dont have access to Delphi, just grab the prebuilt binary from the /bin folder and follow the instructions below.

## Installation:

1) Go edit your Pushover account or set one up:  https://pushover.net/

2) Go get the latest SSL files and place them in the EXE folder:  https://indy.fulgan.com/SSL/

3) Create a folder containing the service exe, dll files, and config file
   wherever you prefer like "C:\ProgramData\[tools]\Drive Space Monitor" 

4) Open a cmd window as admin and navigate to this folder.

5) To install the service into the Windows Service Control Manager type the following:
   DriveSpaceMonitor.exe /install
   
6) Configure the DriveMonitor.ini file.

7) Open Windows Services and right click the "Drive Space Monitor Service" then click properties and
   Navigate to the "Logon" Tab.  Change the logon from "Local System Account" to "Logon As" and put in 
   an appropriate account and password. Click OK
   
8) Now start the service.

Done!

## Uninstall:

1) Stop the service.
2) Open a cmd window as admin and navigate to the folder where you copied it to in Step #1 of installation
3) DriveSpaceMonitor.exe /uninstall

## Alternative Installation:

If you need to install from a batch file or from an installation program, you can use the following:

    sc.exe create DriveSpaceMonitorService start= delayed-auto binPath= "C:\ProgramData\Tools\Drive Space Monitor\DriveSpaceMonitor.exe" obj= "MYUSERNAME" password= "MYPASSWORD"

## Automated installer
Coming soon!

## Authors
Chris McClenny(me), Chris Felder(@rollntider)

## License
MIT License
