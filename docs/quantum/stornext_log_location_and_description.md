July 2012© 2012 Quantum | StorageCare Learning
StorNext
Log Location and Descriptions: The Basics
With StorNext, there two main types of log files:
•	Capture State: This is the collection of information from the platform tools and Storage Manager 
logs. A capture state is also called a snapshot or a collect log. Tech Support asks for these logs 
when troubleshooting a StorNext File System and StorNext Storage Manager installation.
•	cvgather: This is the collection of StorNext-File-System-specific logs. Tech Support asks for 
these logs when troubleshooting a StorNext-File-System-only installation.
Capture State
StorNext logs are constantly updated and stored on the system. You can access and review logs from the system, or you can 
collect a snapshot of the system logs at a given point in time. The capture state is saved in a ZIP file. The following table shows 
the folders contained in this ZIP file, and includes notes about the most important folders.
(/usr/adic/DSM) StorNext File System and StorNext Storage Manager Issues
/data/<file system name>/log (aka /<file system name>/logs/cvlogs)
•	Includes status and errors regarding the file system.
/debug/nssdbg.out            
•	Includes failover/heartbeat activities
(user/adic/MSM) StorNext Storage Manager Issues
/logs/tac/tac_00 *            
•	Includes information related to the library.
(usr/adic/tomcat) StorNext GUI Issues
/logs/stornextgui.log     
•	Includes GUI-related issues.
(/usr/adic/tsm) StorNext Storage Manager Issues
/logs/history/hist_01 *     
•	Includes a history of what users did (TSM CLI commands).
/logs/tac/backup.log         
•	Includes a list of backup issues.
/logs/tac/tac_00 *             
•	Includes information about data movement.
(/var/log*) StorNext File System Issues
On Linux systems, the system log resides in /var/log/messages
On Windows systems, the system log is the system event log.
It contains error and status messages for the operating system and all 
products installed on the system.
* Old files are named numerically (i.e., tac_00_1, tac_00_2)
cvgather
The cvgather program is used to collect debug information from a file system. It creates a tar file of the system’s StorNext File 
System debug logs, configuration, version information, and disk devices. 
The cvgather program collects client debug information on client machines, server information on server machines, and 
portmapper information from both clients and servers. It also collects system log files and StorNext File System log files. 
The log files created by cvgather are named as follows:
•	Pattern:  hostname_filesystemname.logfilename
•	Example: Linux_nh-node-1_snfs1.cvlog 
In the example, Linux_nh-node-1 is the hostname, snfs1 is the filesystemname used with the cvgather command, and .cvlog 
is the logfilename used for all collections of logs created by cvgather.
When a new .cvlog file is created, older versions of this file are renamed. For example:
•	Linux_nh-node-1_snfs1.cvlog is the most recent version of that file.
•	Linux_nh-node-1_snfs1.cvlog_1 is the second most recent version.
•	Linux_nh-node-1_snfs1.cvlog_2 is the third most recent version.
The log files are tar’d and don’t have a specific folder structure. However, the log files included are similar to what is included 
in a capture state, minus the Storage Manager logs.
