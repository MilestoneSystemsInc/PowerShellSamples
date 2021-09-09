# ScheduledLogExport

<img src="ScheduledLogExport_screenshot.png" alt="Screenshot of Task Scheduler in Windows showing the task registered by the script in this sample." width="800">

There are are lot of ways to execute scripts/tasks on a schedule. In Windows, the most common way
to do this is through the Windows Task Scheduler. And there are even multiple ways to execute
PowerShell scripts in Task Scheduler! You can create a standard scheduled task by hand, or by using
some of the PowerShell cmdlets in the ScheduledTasks module, or finally by using the PSScheduledJob
module which is the route I went for this sample.

To use this sample, you can download ScheduledLogExport.ps1 and place it in some folder on your
Windows client or server where you want your log file and log export CSV's to live. For example,
you could place it in `C:\scripts\ScheduledLogExport\`. Then open PowerShell as Administrator
and execute the script. That's it!

## But how does it work?

The script uses the new "ShowDialog" switch parameter in Connect-ManagementServer to give you the
opportunity to successfully connect to your Management Server. Once connected, your login choices
get persisted to disk in a connection.xml file in the same folder. If you provided a password, it
will be encrypted as a secure string automatically using "CurrentUser" scope. This means only your
user account can decrypt that password.

The scheduled task will import that connection.xml file and splat those parameters into the
`Connect-ManagementServer` command. After that, we run the log export and save the output to a
timestamped file in the `exports` subfolder that should now exist in the folder your script is in.

A log file will be created thanks to the use of `Start-Transcript` to give you an idea of how the
task ran during the last execution. The file will be overwritten each time to avoid *eventually*
filling your disk up with logs. Likewise, any exports older than 30 days will be deleted
during each run.

## Instead of CSV

This sample is intended to show one way you can automate log retrieval. Often times a CSV file is
not the right format for your intended purposes. If you instead want to transform and send this
data to another tool like Splunk, ElasticSearch, DataDog, or just another SQL database, you can
modify the sample starting around line 55 and instead of piping the logs to CSV, you could choose
to use any number of PowerShell modules to help connect to the destination system and send the logs
there instead! When you're ready, re-run the script to remove the old scheduled job and register a
new one with the updates you've added.

## Additional thoughts

The PSScheduledJob module is interesting in the way it works. You'll find the scheduled task runs
powershell.exe with a command that loads your scheduled job definition from
`C:\Users\<user>\AppData\Local\Microsoft\Windows\PowerShell\ScheduledJobs`. If something weird
happens and your transcript log file doesn't show it, you might find more information in the
`Output` subfolder under your scheduled job defintion folder. And if your Windows user password
changes, you may need to be sure to login to this machine to make sure the script is still running
since it runs under your user context.

If your Management Server is on a different system than this script, you might need to add the
`Credential` parameter to `Register-ScheduledJob` and provide your Windows user credential unless
you decide to use explicit Windows user authentication or basic user authentication and provide
both a username and password while running the script to create the scheduled job/task.
