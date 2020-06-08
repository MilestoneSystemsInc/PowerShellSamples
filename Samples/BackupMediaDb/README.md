## BackupMediaDb
This sample demonstrates how you could use a mix of features from PowerShell,
MilestonePSTools, and robocopy to backup part of a Milestone media database
on a Recording Server.

The Backup-MediaDb cmdlet is intended to be run directly on a Recording Server
after connecting to the Management Server with the Connect-ManagementServer
MilestonePSTools cmdlet. The Recording Server ID will be autodetected using the
Get-RecorderConfig cmdlet, and the storage configuration for the recorder will
be read from the Management Server. Then each storage configuration will be
checked for tables matching the provided time and device ID criteria.

```powershell
# Backup the last 7 days worth of files from any and all Media Database
# locations on this Recording Server
Connect-ManagementServer
Backup-MediaDb -Destination E:\backup -Start (Get-Date).AddDays(-7) -End (Get-Date)
```