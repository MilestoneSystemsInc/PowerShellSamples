# Instantáneas en intervalos

En este ejemplo se muestra cómo puede programar una tarea en Windows para recuperar instantáneas JPEG de cámaras seleccionadas en un intervalo determinado.

Para probarlo, simplemente ejecute la secuencia de comandos setup.ps1 como administrador. La elevación es necesaria porque creará una tarea programada, pero la tarea en sí no requerirá ni se ejecutará con privilegios elevados.
Asegúrese de ejecutar la secuencia de comandos desde un archivo en lugar de copiar y pegar la secuencia de comandos en una terminal de PowerShell. La secuencia de comandos utiliza la variable automática $PSScriptRoot para determinar el “directorio de trabajo” donde se almacenarán la configuración, el registro y las instantáneas. Por lo tanto, dondequiera que ejecute setup.ps1 será el directorio de trabajo para la tarea programada.

Cuando ejecute la secuencia de comandos, se le pedirá la dirección y las credenciales del servidor de Milestone, luego ingresará el intervalo deseado entre instantáneas en segundos y seleccionará una o más cámaras para incluir a través de la GUI del “Selector de elementos” de Milestone.

A continuación, guarde esta información en un archivo XML mediante Export-CliXml, lo que garantizará que las credenciales se cifren mediante la API de protección de datos de Windows (DPAPI) con el ámbito “CurrentUser”, lo que significa que solo el usuario de Windows actual podrá leer la credencial desde el disco.

Por último, use Register-ScheduledJob para crear una tarea programada en Windows que encontrará en el Programador de tareas en Microsoft\/Windows\/PowerShell\/ScheduledJobs. La tarea programada se iniciará inmediatamente, así como en cada inicio de Windows, lea el archivo config.xml y use la información allí para iniciar sesión en el VMS de Milestone, luego comenzará a guardar instantáneas en el intervalo dado. La secuencia de comandos se ejecutará indefinidamente en un bucle infinito, y dormirá durante el tiempo adecuado entre la toma de instantáneas.

Tenga en cuenta que si hay cientos de cámaras o más, este proceso podría llevar mucho tiempo y las instantáneas se tomarán en serie en lugar de en paralelo.

