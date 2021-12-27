## Activate PTZ Preset Positions
En este ejemplo, aprovecharemos una nueva característica introducida en MilestonePSTools v1.0.75, Send-MipMessage. Consulte el contenido de Invoke-PtzPreset.ps1 para obtener un ejemplo de cómo activar una posición posición prestablecida o recuperar las coordenadas PTZ actuales mediante Send-MipMessage.

En la siguiente secuencia de comandos, encontraremos todas las cámaras con al menos una posición preestablecida PTZ, luego llamaremos a Invoke-PtzPreset en cada una. Luego tomaremos una instantánea de la cámara, guardando una imagen en el disco con la cámara y los nombres de posición prestablecidos en el nombre del archivo.


```powershell
# Pídale a PowerShell que nos muestre mensajes de "información" que normalmente están ocultos / ignorados
$InformationPreference = 'Continue'

# Seleccione todas las cámaras con al menos una posición predefinida PTZ
$cameras = Get-Hardware | Where-Object Enabled | Get-Camera | Where-Object { $_.Enabled -and $_.PtzPresetFolder.PtzPresets.Count -gt 0 }

# Esto es "dot sourcing" donde llamamos a un script externo. En este caso, solo estamos cargando la función Invoke-PtzPreset. Asumiremos que el archivo Invoke-PtzPreset.ps1 está en la misma carpeta que este script.
. .\Invoke-PtzPreset.ps1

foreach ($camera in $cameras) {

    foreach ($ptzPreset in $camera.PtzPresetFolder.PtzPresets) {
        
        Write-Information "Moving $($camera.Name) to $($ptzPreset.Name) preset position"
        Invoke-PtzPreset -PtzPreset $ptzPreset -VerifyCoordinates

        Write-Information "Taking snapshot . . ."
        $snapshotParams = @{
            Live = $true
            Quality = 95
            Save = $true
            Path = "C:\demo"
            FileName = "$($camera.Name) -- $($ptzPreset.Name).jpg"
        }
        $null = $camera | Get-Snapshot @snapshotParams
    }
}
```