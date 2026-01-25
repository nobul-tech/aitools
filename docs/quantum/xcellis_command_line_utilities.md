Service-Only Procedures > Command Line Utilities
The service utilities available via the command line include the following.
How to Add/Change the VIP Address
Overview of VIP Addresses
A VIP is a single network connection defined on an HA (dual-server node) system to point to for server
connections, regardless of which server node is currently operating as the primary (active) server node. While
the VIP is configured on the primary node, using a NIC interface, when it is configured, it automatically saves
a copy of the VIP configuration information to the other nodes in the StorNext cluster (typically the other
server in the HA system). The VIP is configured on a specific interface, meaning that, even though the initial
configuration settings are specific to the primary node they are configured on, when the file updates are made
to the other clustered server(s), the updates to the VIP settings are assigned to the same interface on the
other clustered server(s).
Example (HA server pair):
The VIP is updated to use the MAC address, IP and netmask for the eth0 port (interface) on the primary
server (node 1). When the file is saved, the VIP settings saved on the primary are replicated to node 2, using
the same interface (in this case, eth0) for node 2, but using its' unique MAC address for eth0, but with the
same IP and netmask settings as were used for the primary server node.
Add or change the VIP address
To add or modify the Virtual IP address for the system, log in to the server node operating as primary:
1. Open an SSH connection to the appropriate server and use the IP address assigned to the node on
the Management or LAN Client network, or use the Service Port IP address.
Note: The service port is no longer a dedicated service port. This port might be configured by
the user for use as a metadata or client port with a different IP configuration. If this port has been
reconfigured by the user, then command line access over a network connection requires an
appropriate IP address for your configured system on that network.
Service Port IP addresses:
Node 1 : <service port IP address> (dual-server node systems), the default service port IP
address is 10.17.21.1
Node 2 : <service port IP address> (dual-server node, or supported "HA-ready" single-server
node StorNext appliances), the default service port IP address is 10.17.21.2
close section
2. Initiate an ssh session to the system using Terminal or PuTTY:
To ssh into the system
a. Log in to the command line using the following credentials:
User name: stornext
Password: <StorNext user account password>
Command Line Utilities
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 1/9
Note: password is the default password for the stornext user account. If the
password has been changed, use the current password. The first time you log in, you
are prompted to change the password to a different one.
b. Enter sudo rootsh to gain root user access.
c. Enter the password for the stornext user account again.
close section
3. Verify that the server node you are connected to is operating as primary. Enter:
snhamgr -m status
4. Verify the output is (in green):
LocalMode=default
LocalStatus=primary
RemoteMode=default
RemoteStatus=running
This indicates the "Local" node you are connected to is operating as primary ("LocalStatus=primary"),
and that the other node is operating as secondary ("RemoteStatus=running"). If you do not see this
status, close this PuTTY/terminal session and SSH in to the other server node.
5. Obtain information for the interface you wish to assign for use as a VIP. Enter:
vip_control -i
If you see output similar to the following, there is a VIP assigned to the system.
Example (VIP exists):
NICs: name 'eth0' mac 00155db5e60b desc '' machdep '' IP 192.168.0.188
255.255.255.0
In this example, eth0 has been configured as the VIP, using the default IP address and netmask
assigned to this interface during initial configuration. If you are happy with this configuration, you can
exit this SSH session. However, if you want to add another interface as another VIP for the system,
continue to the next step.
Example (VIP does not yet exist):
If you see this message, there currently is no VIP assigned to the system (HA server pair):
Unable to read VIP file
Followed by information similar to the following:
NICs:
 name 'p2p1' mac a0369f779b48 desc '' machdep ''
 name 'p2p2' mac a0369f779b49 desc '' machdep ''
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 2/9
 name 'p2p3' mac a0369f779b4a desc '' machdep ''
 name 'p2p4' mac a0369f779b4b desc '' machdep ''
## IP 10.20.86.75 255.255.252.0
 name 'bond0' mac ecf4bbdecbd6 desc '' machdep ''
## IP 192.168.1.11 255.255.255.0
 name 'em1' mac ecf4bbdecbd4 desc '' machdep ''
  IP <service port IP address> 255.255.255.0
 name 'em2' mac ecf4bbdecbd5 desc '' machdep ''
## IP 10.20.86.71 255.255.252.0
 name 'idrac' mac 74e6e2fc2237 desc '' machdep ''
Some things to note about this example:
All the available NIC ports on the system are shown, along with information about each one.
Ports p2p1 through p2p3 have not yet been configured, so there is no IP address or netmask
assigned to them yet, meaning they cannot be used as a VIP.
Notice that em2 (management network), and p2p4 are configured. Typically, this is the port you
would define as the system VIP, but it could be any active, configured NIC port on the system.
6. Copy the information you will need to configure the VIP for the interface you will use (MAC address, IP
address, netmask, IPv6 address [if used])
7. Navigate to the correct directory. Enter:
cd /usr/cvfs/bin
8. To configure the VIP, or add another interface to the existing VIP file, enter the vip_control
command, following the specific variables described here:
vip_control -u <vip settings>
Required <vip settings> Syntax
<vip settings> = "<settings for VIP 1>;<settings for VIP 2>;"
The values for the <vip settings> consist of the following comma-separated values: MAC
address, IPV4 VIP, netmask, IPV6 VIP (optional), and then prefix length. Where no value is set,
use commas to separate from the other values. A semi-colon separates first and second VIPs and
closes the string, followed by an ending straight quotation mark.
Note: Adding a second, VIP 2, is optional, not required.
Pro Tip!
To view all the VIP commands available, enter vip_control on the command line, and you will
be presented the options and their syntax.
Example: server node 1 with 1 VIP (typical):
(Using values for em2 from the example output above that didn't yet have a VIP assigned to the
system.)
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 3/9
vip_control -u
"ecf4bbdecbd5,10.20.86.71,255.255.255.0,,;"
Example: server node 1 with 2 VIPs defined:
(Using values for em2 and p2p4 from the example output above that didn't yet have a VIP assigned to
the system.)
vip_control -u "ecf4bbdecbd5,10.20.86.71,255.255.252.0,,;
a0369f779b4b,10.20.86.75,255.255.252.0,,;"
Note: In these examples, IPV6 VIP and prefix length are not used for either VIP address, but the
commas and semi-colons used to separate those fields are still included in the string.
You will see a note similar to the following that identifies that the settings are being written to the
VIP file (in this case, from the eth2 update example [the first VIP example, above], since there was no
VIP file this would create a new vip file). Then, the VIP is configured, and the configuration updates
would be replicated to other server nodes in the StorNext cluster (the "Telling others about IP..."
portion):
Writing new VIP file
Running '/sbin/ifconfig em2:ha 10.20.86.71 netmask 255.255.255.0 up'
Telling others about IP (/usr/cvfs/lib/takeover_ip -d em2:ha -m
ecf4bbdecbd5 -i 10.20.86.71)
9. Update the firewall rules for the node operating as the primary. Enter:
/opt/DXi/scripts/netcfg.sh --reset_snvip
10. Close the SSH connection for the operating as the primary.
The procedure is complete.
close section
close section
How to Reset the StorNext User Password
This section explains how to boot the server node so that the stornext user password can be reset.
To reset the stornext user password:
1. Connect the service laptop to the BMC port and launch the BMC console. Refer to Access the BMC for
more information.
2. Run the following command to reboot the server node and then wait for the GRUB menu to appear on the
console for the Linux boot:
systemctl -i reboot
3. Select option e to prompt for the GRUB password.
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 4/9
4. Enter the GRUB username: root
5. Enter the GRUB password Qa@Gr64!
6. Use the arrow keys to move down to the line that begins with linux.
7. Add <space>init=/bin/bash to the end of the boot line and press Ctrl-x to continue the boot
process.
Note: The system then boots to a Linux prompt without a password prompt.
8. Enter passwd stornext at the Linux prompt
9. Enter the factory default password of password when prompted.
10. Perform a reset of the node by navigating to the Power Control menu on the BMC console and select
Set Power Reset.
11. On system reboot, have the customer set the stornext password to a unique value and record it
somewhere before leaving the customer site.
close section
How to Set the IPMI Password
You can change the default factory password for the IPMI remote login/BMC user by selecting the Set IPMI
Password option from the Service Menu and entering a custom password.
Note: The default password from the factory is available on the pull out tab on the front of the server.
Do the following to set the IPMI password:
1. Log in to the CLI of the server node that you are modifying:
To log in to the CLI
a. Open an SSH connection to the appropriate server and use the IP address assigned to the node
on the Management or LAN Client network.
b. Initiate an ssh session to the system using Terminal or PuTTY:
To ssh into the system
a. Log in to the command line using the following credentials:
User name: stornext
Password: <StorNext user account password>
Note: password is the default password for the stornext user account. If the
password has been changed, use the current password. The first time you log in,
you are prompted to change the password to a different one.
b. Enter sudo rootsh to gain root user access.
c. Enter the password for the stornext user account again.
close section
close section
2. At the prompt, enter the following to open the Service Menu as the admin user:
sh /opt/DXi/scripts/service.sh -admin
3. Select Hardware Configuration > Setup IPMI > Set IPMI Password.
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 5/9
Example
*** Service Menu ***
0) Hardware Configuration   >>> - Tools for Configuring Hardware.
1) Serial Numbers           >>> - Tools for Node and System Serial Numbers.
2) More Tools               >>> - Miscellaneous Tools.
Your Choice ('q' to Exit this Menu): 0
*** Service Hardware Configuration Menu ***
0) Setup IPMI               >>> - Setup the iDRAC/IPMI.
1) Factory Detect Hardware      - Create Factory List of Detected Hardware.
Your Choice ('q' to Exit this Menu): 0
*** Service Setup IPMI Menu ***
0) Configure IPMI    - Configure IPMI network Information.
1) Show IPMI         - Show IPMI network Information.
2) Set IPMI Password - Set IPMI remote login password.
3) Reboot IPMI       - Reboot the IPMI controller.
Your Choice ('q' to Exit this Menu): 2
Enter the new password for the IPMI remote login.
The password must be at least 8 characters and contain a lowercase
letter, an uppercase letter, and a non-alpha character.
To exit, press ENTER when prompted for the password.
Enter password:
4. Enter a password for the IPMI remote login/BMC user.
5. Exit the Service Menu session.
6. Exit your rootsh session.
7. Exit the SSH connection to the server.
close section
How to Reset the IMPI/BMC Password to the Factory Default
This section provides information on how to reset the IMPI/BMC password to the factory default.
Note: The default password from the factory is available on the pull out tab on the front of the server.
Do the following to reset the IMPI/BMC password to the factory default:
1. Log in to the CLI of the server node that you are modifying:
To log in to the CLI
a. Open an SSH connection to the appropriate server and use the IP address assigned to the node
on the Management or LAN Client network.
b. Initiate an ssh session to the system using Terminal or PuTTY:
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 6/9
To ssh into the system
a. Log in to the command line using the following credentials:
User name: stornext
Password: <StorNext user account password>
Note: password is the default password for the stornext user account. If the
password has been changed, use the current password. The first time you log in,
you are prompted to change the password to a different one.
b. Enter sudo rootsh to gain root user access.
c. Enter the password for the stornext user account again.
close section
close section
2. At the prompt, enter the following:
Note: After you execute the following command, the IPMI/BMC will reboot.
/opt/smc/bin/ipmicfg -fd 2
Example Output
Reset to the factory default completed.
close section
How to use the Wipe/Restore Utility
You can use the wipe/restore utility to wipe the StorNext install and HA shared file system off of StorNext
Appliances. The utility then restores the appliance to factory state including the HA shared file system and
StorNext without having to reinstall StorNext from DVD. This utility also preserves network configuration
settings, so network configuration will be left intact and will be used by the restored system.
Note: This utility only applies to StorNext Appliances.
Caution: Only run this utility when you are not actively using the system.
On the Secondary Node
To use the wipe/restore utility, begin by accessing the server Node operating as the secondary:
1. Open an SSH connection to the appropriate server and use the IP address assigned to the node on
the Management or LAN Client network, or use the Service Port IP address.
Service Port IP addresses:
Node 1 : <service port IP address> (dual-server node systems), the default service port IP
address is 10.17.21.1
Node 2 : <service port IP address> (dual-server node, or supported "HA-ready" single-server
node StorNext appliances), the default service port IP address is 10.17.21.2
close section
2. Initiate an SSH session to the system using Terminal or PuTTY:
a. Log in to the command line using the following credentials:
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 7/9
User name: stornext
Password: <StorNext user account password>
Note: password is the default password for the stornext user account. If the password
has been changed, use the current password. The first time you log in, you are prompted
to change the password to a different one.
b. Enter sudo rootsh to gain root user access.
c. Enter the password for the stornext user account again.
3. At the command prompt type:
sh /opt/DXi/scripts/reset_SN.sh
close section
On the Primary Node
Continue by logging onto the MDC Node operating as the primary:
1. Open an SSH connection to the appropriate server and use the IP address assigned to the node on
the Management or LAN Client network, or use the Service Port IP address.
Service Port IP addresses:
Node 1 : <service port IP address> (dual-server node systems), the default service port IP
address is 10.17.21.1
Node 2 : <service port IP address> (dual-server node, or supported "HA-ready" single-server
node StorNext appliances), the default service port IP address is 10.17.21.2
close section
2. Initiate an SSH session to the system using Terminal or PuTTY:
a. Log in to the command line using the following credentials:
User name: stornext
Password: <StorNext user account password>
Note: password is the default password for the stornext user account. If the password
has been changed, use the current password. The first time you log in, you are prompted
to change the password to a different one.
b. Enter sudo rootsh to gain root user access.
c. Enter the password for the stornext user account again.
3. From the command prompt, enter:
sh /opt/DXi/scripts/reset_SN.sh
close section
Convert to HA and restart the system
1. Convert the system from a single-node mode to an HA configuration.
2. Restart the metadata array and MDC nodes.
close section
close section
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 8/9
Core Files and the Trimcores Cron Job Process
The trimcores cron job process runs hourly on both MDC nodes and checks for new core files located in the
/scratch/core/ directory on the node. If a new core file is detected, a RAS ticket is generated to report the
core file, and the core file name is changed to <corefile>-reported.
Core files remain on the system for 30 days before they are deleted from the system. After 30 days, an empty
text file named <corefile>-deleted remains in the /scratch/core/ directory to provide evidence that
a core file was detected and deleted by the trimcores cron job process.
close section
Troubleshooting Tools
The following tools may be used for troubleshooting the appliance in the field.
Tool Name Location Use
iozone /opt/iozone/bin/iozone This is a file system benchmark utility, used for measuring
file I/O.
netperf /usr/bin/netperf Network bandwidth testing. This tool times the transmission
and reception of data between two systems using the User
Datagram Protocol (UDP) or Transmission Control Protocol
(TCP) protocols.
close section

Send us your comments
© Quantum Corporation. All rights reserved. | 6-68703-02 | Initial publication date: June 21, 2022 | Last updated on Wednesday, November 5, 2025.
11/20/25, 10:56 AM Command Line Utilities
https://qsweb.quantum.com/kb/flare/Content/appliances/Gen3/DocSite/Index.php#ServiceOnly/CommandLine-utilities.php?TocPath=Service-Only%2520Procedures… 9/9
