# Informar es divertido

Las funciones y los ejemplos de esta carpeta muestran los métodos para recuperar información con fines de generación de informes. Probablemente existan tantos conjuntos diferentes de datos deseados por los clientes y operadores de VMS como instalaciones de VMS en el mundo, por lo que estas herramientas deben combinarse o utilizarse como inspiración según sea necesario para que usted obtenga los datos que necesita.

## Una nota sobre las interfaces no compatibles

Milestone proporciona una gran cantidad de funcionalidades en MIP SDK. Casi todo el módulo MilestonePSTools está escrito mediante componentes puros de MIP SDK. Cambiar y ampliar MIP SDK al tiempo que se maximiza la compatibilidad con los sistemas anteriores o posteriores y se minimizan los cambios importantes es un verdadero desafío y tengo un profundo respeto por el equipo del Kit de desarrollo de software (SDK) por sus esfuerzos para llevar la funcionalidad tan necesaria a las manos de desarrolladores externos.
Sin embargo, existen algunas funciones que el MIP SDK aún no puede realizar y dado que un número muy pequeño de usuarios necesita o desea acceder a estas funciones, el equipo del SDK tardará algún tiempo en abordar esas necesidades e implementar nuevas características con soporte a largo plazo. Mientras tanto, con un poco de investigación y persuasión, ocasionalmente podemos superar estas limitaciones utilizando API que no estaban destinadas a ser utilizadas por el público.
Encontrará varias funciones con ciertas interfaces que no son intuitivas y carecen de documentación en los documentos en línea del MIP SDK. Estas funciones estarán claramente documentadas en los comentarios de ayuda y no se promete absolutamente ningún soporte cuando las interfaces no compatibles utilizadas por estas funciones cambian entre versiones y la compatibilidad con versiones anteriores o posteriores se pierda o empeore.

## Get-VmsCameraDiskUsage

Una solicitud común que actualmente no se ha cumplido con MIP SDK es la capacidad de recuperar la cantidad de almacenamiento utilizada por cámara. Es posible extraer el espacio utilizado/disponible para una ubicación de almacenamiento en directo o de archivo, pero no cámara por cámara.

–“Pero la información está en Management Client", le escucho decir. “Entonces, ¿por qué no podemos obtenerlo con el SDK? ¿El Management Client no usa el SDK?” Bueno, en realidad no, no es así. Gran parte del Management Client hace uso de interfaces internas donde los desarrolladores tienen la flexibilidad de agregar/cambiar capacidades entre versiones mientras mantienen las interfaces MIP SDK más estables con el tiempo. De todos modos, mucho de lo que se hace en Management Client es irrelevante para la mayoría de los desarrolladores de integración de MIP SDK.

En pocas palabras, esta función usa una interfaz de cliente WCF que no es compatible para uso externo. El método de uso de esta interfaz es muy similar a las otras interfaces _compatibles_ como IConfigurationService, por ejemplo, y técnicamente cualquier persona que conozca la URL web del servicio puede usarla. La autenticación de la interfaz es la misma que cualquier otra interfaz WCF de Milestone y esta función autentifica y usa esta API de forma transparente en su nombre. Así es como se ve la salida: Los valores de UsedSpace están en bytes, y simplemente ignore los valores de AvailableSpace por ahora. Al parecer puede haber algún tipo de error de desbordamiento en el que estos valores no tengan mucho sentido; es probable que el campo no se use en Management Client. Si necesita conocer AvailableSpace, navegue hasta los objetos de almacenamiento/archivo `$RecordingServer.StorageFolder.Storages[$i]` or `$RecordingServer.StorageFolder.Storages[$i].ArchiveStorageFolder.ArchiveStorages[$j]`.

```powershell
PS C:\> Get-Hardware | Get-Camera | Get-VmsCameraDiskUsage | Format-Table *

CameraId                             StorageId                            RecorderId                           UsedSpace AvailableSpace IsOnline
--------                             ---------                            ----------                           --------- -------------- --------
3c25ff7a-7c76-49bd-bda0-116f5e051e48 cce0ef0f-36b1-4221-964d-e5de1f641741 72080191-d39d-4229-b151-65bcd740c393      4513   157586161664     True
afa846f8-846c-4932-b206-c1c6c24e0b5f def84b4a-1e7a-4f99-ac5f-671ae76d520b 72080191-d39d-4229-b151-65bcd740c393      4519   157586161664     True
c2733741-0c71-4197-89d2-030339c7a9ea def84b4a-1e7a-4f99-ac5f-671ae76d520b 72080191-d39d-4229-b151-65bcd740c393 161278294   157586161664     True
c2733741-0c71-4197-89d2-030339c7a9ea e96f206b-3ecd-421a-906b-e32393b4bedb 72080191-d39d-4229-b151-65bcd740c393 705524466 12260420734976     True
c2733741-0c71-4197-89d2-030339c7a9ea 2358075f-2291-4c43-86c8-9d6351f2ed59 72080191-d39d-4229-b151-65bcd740c393  71165280   197973835776     True

PS C:\>
```
