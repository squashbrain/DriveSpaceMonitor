# DriveSpaceMonitor
Drive Space Monitoring Tool + Pushover Notifications

This DriveSpaceMonitor is a Windows service which will monitor Drive space on one or more drives.  
In the event that the free drive space remaining reaches a pre-set trigger point, it will send a 
Pushover alert to a technician to handle the problem.


Go edit your Pushover account or set one up:
https://pushover.net/

Go get the latest SSL files and place them in the EXE folder:
https://indy.fulgan.com/SSL/




Installation:
-----------------------------------------------------
1) No true installation is needed.  Just put the folder containing the service exe, dll files, and config file
   into a folder of your choice like "C:\ProgramData\[tools]\Drive Space Monitor" 

2) Open a cmd window as admin and navigate to this folder.

3) To install the service into the Windows Service Control Manager type the following:
   DriveSpaceMonitor.exe /install
   
4) Configure the DriveMonitor.ini file.

5) Open Windows Services and right click the "Drive Space Monitor" service then click properties and
   Navigate to the "Logon" Tab.  Change the logon from "Local System Account" to "Logon As" and put in 
   an appropriate account and password. Click OK
   
6) Now start the service.

Done!



Uninstall:
-----------------------------------------------------
1) Stop the service.
2) Open a cmd window as admin and navigate to the folder where you copied it to in Step #1 of installation
3) DriveSpaceMonitor.exe /uninstall
