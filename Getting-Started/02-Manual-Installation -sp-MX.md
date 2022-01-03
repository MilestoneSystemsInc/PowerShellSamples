# Instalación manual

Si su VMS de Milestone está "aislado" o por cualquier otra razón no puede instalar un módulo de PowerShell con el cmdlet `Install-Module` que lo descarga directamente desde la Galería de PowerShell, aún puede instalar MilestonePSTools. Síganos para aprender cómo.

## Descargar los archivos nupkg

¿Qué se supone que es un archivo nupkg? Para empezar, puedes pronunciarlo “nup-keg”, ¡lo cual es divertido! Y significa “Paquete NuGet”. NuGet es el nombre del administrador de paquetes de Microsoft introducido principalmente para administrar paquetes de aplicaciones .NET. En este caso, "paquete" significa uno o más archivos DLL y algunas instrucciones básicas para dónde van. Antes de 2010, la mayoría de los desarrolladores de .NET copiaban manualmente alrededor de archivos DLL y agregaban referencias a ellos cuando era necesario. Hizo que fuera muy complicado compartir bibliotecas reutilizables. Ahora, con NuGet.org, puede hacer referencia a un paquete por su nombre y descargar/desempaquetar/usar automáticamente ese paquete.

Para descargar manualmente MilestonePSTools, deberá descargar dos archivos. El primero es el "archivo nupgk sin formato" MilestonePSTools y el segundo es el MipSdkRedist nupkg. El módulo MipSdkRedist es el contenedor utilizado para el MIP SDK de Milestone en el que se basa MilestonePSTools. Estos son los vínculos a los dos módulos de PowerShell en PSGallery. Una vez allí, haga clic en **Descarga manual** en **Opciones de instalación** y luego haga clic en **Descargar el archivo nupkg sin procesar**.

- [MilestonePSTools](https://www.powershellgallery.com/packages/MilestonePSTools)
- [MipSdkRedist](https://www.powershellgallery.com/packages/MipSdkRedist)

Estos archivos nupkg son en realidad archivos ZIP. Si agrega la extensión .zip al archivo, puede ver/extraer el contenido como cualquier otro archivo zip. Así es como se ven los contenidos de MilestonePSTools:

![Captura de pantalla del contenido del archivo nupkg de MilestonePSTools](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/MilestonePSTools-nupkg-contents.png?raw=true)

Antes de extraer los archivos ZIP, asegúrese de hacer clic derecho en ambos archivos y abrir **Propiedades**. Si ve una casilla de verificación para "desbloquear" los archivos, debe hacerlo antes de extraerlos. De lo contrario, *también* se bloqueará cada archivo extraído individualmente.

Al extraer los archivos del módulo, el mejor lugar para colocarlos es en una de las ubicaciones en las que PowerShell busca *automáticamente* los módulos de PowerShell. Si instala el módulo *solo para usted*, debe colocar el módulo en su directorio Documentos en `~\Documents\WindowsPowerShell\Modules`. Es posible que las carpetas no existan todavía. De ser así, está bien que las cree usted mismo.

Como alternativa, si desea que los módulos estén disponibles para cualquier usuario de un equipo local (útil si desea que una cuenta de servicio, un sistema local o un servicio de red acceda a ellos desde una tarea programada), puede colocarlos en `C:\Program Files\WindowsPowerShell\Modules.`

En la estructura de la carpeta Módulos, el primer nivel incluye una carpeta que coincide con el nombre del módulo, y la subcarpeta contiene una o más versiones de ese módulo donde el nombre de la carpeta coincide con la versión exacta del módulo tal como se define en el archivo `*.psd1` en la raíz de la carpeta del módulo específico. En el siguiente ejemplo, tenemos MilestonePSTools versión 21.1.451603, y dentro de esa carpeta están los contenidos de la captura de pantalla anterior, de modo que MilestonePSTools.psd1 existe dentro de la carpeta llamada "21.1.451603".

```text
+---Modules
    +---MilestonePSTools
    |   \---21.1.451603
    +---MipSdkRedist
    |   \---21.1.1
```

Una vez que haya extraído los módulos y los haya colocado en la ubicación correcta, debería poder ejecutar `Import-Module MilestonePSTools` y tanto MipSdkRedist como MilestonePSTools se cargarán en su sesión de PowerShell. Si recibe un mensaje de error, consulte [01-CommonErrors](01-CommonErrors.md) para ver si ya hemos compartido algunos consejos sobre cómo solucionarlo.