## BackupMediaDb
En este ejemplo se muestra cómo puede usar una combinación de características de PowerShell, MilestonePSTools y robocopy para realizar copias de seguridad de parte de una base de datos multimedia de Milestone en un servidor de grabación.

El cmdlet Backup-MediaDb está diseñado para ejecutarse directamente en un servidor de grabación después de conectarse al servidor de gestión con el cmdlet Connect-ManagementServer MilestonePSTools. El identificador del servidor de grabación se detectará automáticamente mediante el cmdlet Get-RecorderConfig y la configuración de almacenamiento de la grabadora se leerá desde el servidor de gestión. A continuación, se comprobará cada configuración de almacenamiento en busca de tablas que coincidan con los criterios de tiempo e identificación de dispositivo proporcionados.


```powershell
# Backup the last 7 days worth of files from any and all Media Database
# locations on this Recording Server
Connect-ManagementServer
Backup-MediaDb -Destination E:\backup -Start (Get-Date).AddDays(-7) -End (Get-Date)
```