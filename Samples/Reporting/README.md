# Reporting is fun

The functions and examples in this folder demonstrate methods of retrieving information for reporting purposes. I suspect there are as many different sets of data desired by customers and operators of a VMS as there are VMS installations in the world, so these tools should be combined and/or used as inspiration to the extent necessary to get the data you need.

## Note about unsupported interfaces

Milestone provides a ton of functionality in the MIP SDK. Almost the entire MilestonePSTools module is written using pure MIP SDK components. Changing and extending MIP SDK while maximizing backward/forward compatibility and minimizing breaking changes is a challenge and I have a deep respect for the team for their efforts to bring much needed functionality to the hands of 3rd party developers.

There are things the MIP SDK cannot yet do however, and since a very small number of users need/want access to these things, it will take some time for the SDK team to address those needs and implement new features with long term support. Meanwhile, with some investigation and persuasion, we can occasionally overcome these limitations using API's that were never intended to be used by the public.

You will find a small handful of functions where certain interfaces are used that are unintuitive and lack documentation in the online MIP SDK docs. These functions will be clearly documented in the help comments, and absolutely no support is promised when the unsupported interfaces used by these functions changes between versions and backwards/forwards compatibility is lost or worse.

## Get-VmsCameraDiskUsage

One common request that is currently unfulfilled by MIP SDK is the ability to retrieve the amount of storage used on a per-camera basis. It's possible to pull the space used/available for a live or archive storage location, but not on a camera by camera basis.

I hear you - the information is in the Management Client right? So why can't we get it with the SDK? Doesn't the Management Client use the SDK? Well, no actually! A lot of the Management Client makes use of internal interfaces where developers have the flexibility to add/change capabilities between versions while keeping the MIP SDK interfaces more stable over time. A lot of what is done in the Management Client is irrelevant to most MIP SDK integration developers anyway.

Long story short, this function uses a WCF client interface that is not supported for external use. The method of using this interface is very similar to the other _supported_ interfaces like the IConfigurationService for example and technically anyone who knows the web URL for the service can use it. The authentication for the interface is the same as any other Milestone WCF interface and this function transparently authenticates and uses this API on your behalf. Here's what the output looks like. The UsedSpace values are in bytes, and just ignore the AvailableSpace values for now. It seems like there may be some sort of overflow error where these values don't make a lot of sense - the field is probably not used in Management Client. If you need to know the AvailableSpace you should navigate down to the storage/archive objects under `$RecordingServer.StorageFolder.Storages[$i]` or `$RecordingServer.StorageFolder.Storages[$i].ArchiveStorageFolder.ArchiveStorages[$j]`.

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
