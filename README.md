# THIS IS NOT A DRAG AND DROP SCRIPT
This script is used as a tool to create and get data for player groups.
There are no jobs or anything included with these files.

## UI:
![image](https://user-images.githubusercontent.com/7463741/162239943-d7205577-1974-41b8-a8bc-7b67a82d4dad.png)

![image](https://user-images.githubusercontent.com/7463741/162240030-5f4fd63e-2137-48fc-bfcb-258076f087fb.png)



## Exports:

### Client Side
```
-- Returns Client side job stage
exports["ps-playergroups"]:GetJobStage()

-- Returns Clients current groupID
exports["ps-playergroups"]:GetGroupID()

-- Returns if the Client is the group leader.
exports["ps-playergroups"]:IsGroupLeader()
```

### Server Side
```
-- Returns group's leader src
exports["ps-playergroups"]:GetGroupLeader(groupID)

-- Returns group's job status.
exports["ps-playergroups"]:getJobStatus(groupID)

-- Sets a group job status.
exports["ps-playergroups"]:setJobStatus(groupID, status)

-- Gets number of players in a group.
exports["ps-playergroups"]:getGroupSize(groupID)

-- Returns player IDs inside a table.
exports["ps-playergroups"]:getGroupMembers(groupID)

-- Creates a blip for everyone in a group.
exports["ps-playergroups"]:CreateBlipForGroup(groupID, name, label, coords, sprite, color, scale, route)

-- Remove a blip for everyone in a group with the matching blip name.
exports["ps-playergroups"]:RemoveBlipForGroup(groupID, name)

-- Finds the groupID the player is currently in. If they are not in any then it returns 0.
exports["ps-playergroups"]:FindGroupByMember(playerID)
```
