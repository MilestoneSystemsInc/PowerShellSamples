# Retrieve all Transact Sources using the TCP Client Transact Connector and
# output the name, host, port and retention properties.
# NOTE: This requires MilestonePSTools 1.0.71 or greater.

# Items in a VMS configuration have a 'Kind' property which defines what type
# of object it is, or what types of objects it contains in the event it's a 
# container with child items in it. We need the GUID value used for items of
# Transact type or 'Kind'.
$transactKind = (Get-Kind -List | Where-Object DisplayName -eq Transact).Kind

foreach ($item in Get-PlatformItem -Kind $transactKind) {
    # The value a20d8523-547b-4bb3-b5aa-7899c62c68f6 is the ID for the built-in
    # TCP Client transact connector. This script ignores other connectors as
    # they may have different property names.
    if ($item.Properties['TransactConnectorId'] -notlike "a20d8523-547b-4bb3-b5aa-7899c62c68f6") {
        continue
    }

    $result = [pscustomobject]@{
        Name = $item.Name
        Host = $item.Properties["_HOST"]
        Port = $item.Properties["_PORT"]
        Retention = $item.Properties["Retention"]
    }

    Write-Output $result
}