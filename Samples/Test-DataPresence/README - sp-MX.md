## Test Data Presence

En este cmdlet (o grupo de cmdlets) probamos la presencia de datos entre un StartTime y EndTime determinados para dispositivos de cualquier tipo, incluidas cámaras, micrófonos, altavoces y metadatos.

El método utilizado para comprobar la presencia de datos es recuperar una instantánea en el StartTime dado y comprobar el valor de la propiedad DateTime. Si está entre StartTime y EndTime, sabemos que hay al menos _algunos_ datos dentro del lapso de tiempo dado.

Gracias al comportamiento y a las propiedades adicionales disponibles en los datos de reproducción, podemos determinar a partir de esa única instantánea si hay algún dato disponible en todo el lapso de tiempo. Ya sea que la instantánea sea para una cámara, micrófono, altavoz o metadatos.

Al llamar a “GetNearest ([DateTime])” en una fuente de datos en MIP SDK, se devolverá un fotograma de datos si existe algo disponible y será algún tiempo antes o después del valor DateTime dado. Junto con los datos habrá valores que indican el valor DateTime del siguiente fotograma de datos disponible y el fotograma de datos anterior (si está disponible).

Por lo tanto, si los datos devueltos son _anteriores_ a StartTime, y el valor de NextDateTime está entre StartTime y EndTime, podemos afirmar con seguridad que existen datos disponibles en ese lapso de tiempo.

Y si el fotograma más cercano está _después_ de EndTime, sabemos que la imagen más cercana a StartTime es posterior de EndTime, por lo que no existen datos presentes entre StartTime y EndTime.

El cmdlet Test-DataPresence acepta un elemento de configuración de cualquiera de los cuatro tipos de datos y pasa la solicitud a funciones más específicas como Test-VideoPresence, Test-AudioPresence o Test-MetadataPresence. Pero las tres funciones operan de manera muy similar, cada una haciendo uso de las clases de fuente de datos coincidentes del MIP SDK para consultar la base de datos multimedia.

```powershell
$InformationPreference = 'Continue'
$server = Read-Host -Prompt "Server Address"
$credential = Get-Credential

do {
    $isBasic = Read-Host -Prompt "Basic user? (y/n)"
} while ('y', 'n' -notcontains $isBasic)

try {
    Write-Information "Connecting to $server as $username"
    $connected = $false
    Connect-ManagementServer -Server $server -Credential $credential -BasicUser:($isBasic -eq 'y')
    Write-Information "Connected"
    $connected = $true

    foreach ($lock in Get-EvidenceLock) {
        $lockHasData = $false
        $cameras = $lock.DeviceIds | Foreach-Object { try { Get-Camera -Id $_ } catch { } }
        foreach ($camera in $cameras) {
            $dataExists = $camera | Test-DataPresence -StartTime $lock.StartTime -EndTime $lock.EndTime
            if ($dataExists) {
                $lockHasData = $true
                break;
            }
        }

        if (-not $lockHasData) {
            $lock
        }
    }
}
catch {
    throw
}
finally {
    if ($connected) {
        Disconnect-ManagementServer
    }
}
```
