# Trabajar con reglas

Milestone introdujo soporte para trabajar con reglas en la versión 2020 R1, y el soporte se ha expandido en las versiones lanzadas desde entonces. Inicialmente había muchas acciones de regla que, si estaban presentes, evitarían que la regla se devolviera al solicitar elementos secundarios de /RuleFolder. En la versión 2020 R3 se admiten las acciones de reglas más comunes y la funcionalidad es mucho más utilizable.

Dicho esto, actualmente no hay funciones/cmdlets integrados en MilestonePSTools para manipular reglas desde PowerShell. Parte de esto se debe al tiempo limitado disponible para extender MilestonePSTools, la otra parte es el desafío de diseñar funciones simples para trabajar con un concepto e interfaz complejos.

Las secuencias de comandos de esta carpeta son ejemplos funcionales de cómo puede trabajar con reglas y se agregarán más adelante a medida que el tiempo lo permita. Estas funciones pueden llegar al módulo MilestonePSTools, o tal vez se creará un submódulo como "MilestonePSTools.Rules", ya que cualquier función desarrollada para trabajar con reglas son efectivamente solo arreglos creativos de las funciones Get-ConfigurationItem, Invoke-Item y Set-ConfigurationItem que a su vez envuelven el proxy WCF IConfigurationService. Es posible que tenga una opinión diferente sobre cómo se podría implementar la compatibilidad con las reglas en PowerShell, y al mantener nuestras versiones de opinión fuera del espacio de nombres del módulo MilestonePSTools, puede ser más fácil para usted hacer las cosas a su manera sin preocuparse por las colisiones de nombres de funciones.


## Get-VmsRule

Esta función es un contenedor muy simple alrededor de la función `Get-ConfigurationItem` existente, que es a su vez un contenedor alrededor del cliente WCF IConfigurationService que interactúa directamente con la API de configuración en el servidor de gestión. He agregado el prefijo Vms ya que existe una buena posibilidad de que `Get-Rule` pueda colisionar con cualquier número de otros módulos (piense en firewalls, antivirus, etc.).

Admite comodines y tiene un aspecto similar al de esto cuando se importa a la sesión de PowerShell y se llama a un conjunto predeterminado de reglas de VMS.

```powershell
PS C:\> Get-VmsRule | select DisplayName, ItemType, Path, @{ Name = 'Enabled'; Expression = { $_.EnableProperty.Enabled } }

DisplayName                               ItemType Path                                       Enabled
-----------                               -------- ----                                       -------
Default Start Audio Feed Rule             Rule     Rule[162fdb73-e0dc-4a2d-baa6-54b0d2b16684]    True
Default Record on Motion Rule             Rule     Rule[3307c095-a170-49d3-ab11-1baf8783acb9]    True
Default Record on Bookmark Rule           Rule     Rule[4ce46d3e-c4c7-46b2-a580-fc98cdc24611]    True
Default Goto Preset when PTZ is done Rule Rule     Rule[7aa28f82-f3ff-4398-9781-061299178c7f]   False
Default Start Feed Rule                   Rule     Rule[e34e9353-e6f5-43ff-8e8f-d4a558159b2b]    True
Default Record on Request Rule            Rule     Rule[fa2f8209-8d9b-4580-a6eb-17e58c99a610]    True
Default Start Metadata Feed Rule          Rule     Rule[fe61841f-544e-44d7-b7a8-cd709195162d]    True



PS C:\> 
```

## Remove-VmsRule

Esta es una función un poco más compleja que Get-VmsRule, pero sigue siendo un contenedor relativamente simple alrededor de las funciones Get-ConfigurationItem e Invoke-Method que utilizan la API de configuración para modificar la configuración de VMS. Esto es lo que se vería al eliminar la “Regla de fuente de audio de inicio predeterminada” usando comodines en el nombre de la regla (si realmente desea realizar la eliminación, puede omitir el switch WhatIf).

```powershell
PS C:\> Remove-VmsRule -Name 'Default*Audio*' -WhatIf
What if: Performing the operation "Remove Rule" on target "Default Start Audio Feed Rule".

PS C:\> 
```
