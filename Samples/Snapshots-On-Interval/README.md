# Snapshots On Interval

This sample demonstrates how you can schedule a task in Windows to retrieve JPEG snapshots from select cameras on a given interval.

To try it out, simply run the setup.ps1 script as Administrator. Elevation is required because you'll be creating a scheduled task,
but the task itself will not require, or run with elevated privileges.

Make sure to run the script from a file rather than copying and pasting the script into a PowerShell terminal. The script uses
the $PSScriptRoot automatic variable to determine the "working directory" where the configuration, log, and snapshots will be stored.
So wherever you run setup.ps1 from will be the working directory for the scheduled task.

When you run the script, you will be prompted for Milestone server address and credentials, then you will enter the desired interval
between snapshots in seconds, and you will select one or more cameras to be included via the Milestone "Item Picker" GUI.

We then save this information to an XML file using Export-CliXml which will ensure the credentials are encrypted using the Windows
Data Protection API (DPAPI) with "CurrentUser" scope meaning only the current windows user is able to read the credential from disk.

Finally, we use Register-ScheduledJob to create a scheduled task in Windows which you'll find in Task Scheduler under
Microsoft/Windows/PowerShell/ScheduledJobs. The scheduled task will start immediately, and also on every Windows startup, read the
config.xml file and use the information there to login to the Milestone VMS, then begin saving snapshots on the given interval. The
script will run indefinitely in a never-ending loop, sleeping for an appropriate time between taking snapshots.

Note that if there are hundreds of cameras or more, this process could take a long time and the snapshots are being taken in serial
fashion rather than in parallel.
