# Superbullet Project - Data Store System Guide

## Overview

The Superbullet project uses a three-layer data store system built on ProfileService library:

1. **ProfileTemplate.lua** - Defines the data structure
2. **ProfileService.lua** - Server-side data management (Knit Service)
3. **DataController.lua** - Client-side data access (Knit Controller)

This system uses **ProfileStore** (by loleris/MAD STUDIO) for session locking and auto-saving.

---

## Architecture

```
[CLIENT]                    [SERVER]                    [DATASTORE]
DataController.lua  <--->   ProfileService.lua   <--->  ProfileStore
    |                            |                           |
    |-- Data property            |-- Profiles table         |-- "OriginalData1"
    |-- GetPlayerData()          |-- GetProfile()           |-- Player_[UserId]
    |-- WaitUntilProfileLoaded() |-- ChangeData()           |
    |                            |-- Client.GetData         |
    |                            |-- Client.UpdateSpecificData
```

---

## File 1: ProfileTemplate.lua

**Location:** `src/ReplicatedStorage/SharedSource/Datas/ProfileTemplate.lua`

### Purpose
Defines the default data structure for new player profiles. This is the "schema" that all player data will follow.

### Current Structure
```lua
local ProfileTemplate = {
    -- Empty by default - add your data structure here
}
return ProfileTemplate
```

### Example Usage
```lua
-- Add fields to ProfileTemplate to define player data structure
local ProfileTemplate = {
    Coins = 0,
    Level = 1,
    Inventory = {},
    Settings = {
        MusicVolume = 1,
        SFXVolume = 1,
    },
    Stats = {
        TotalPlayTime = 0,
        GamesPlayed = 0,
    },
}
```

### How It Works
- When a new player joins, ProfileService creates their profile using this template
- The `Reconcile()` method fills missing fields from the template into existing profiles
- This ensures backward compatibility when you add new fields

---

## File 2: ProfileService.lua (SERVER)

**Location:** `src/ServerScriptService/ServerSource/Server/ProfileService.lua`

### Purpose
Server-side Knit Service that manages player data sessions, handles auto-saving, and provides data access methods.

### Key Components

#### 1. Profile Store Initialization
- **Store Name:** `"OriginalData1"`
- Uses `ProfileStore.New("OriginalData1", ProfileTemplate)`
- Automatically handles session locking and auto-saves

#### 2. Profiles Table
- `Profiles[player] = profile object`
- Stores all currently loaded player profiles
- Cleared when player leaves

#### 3. Key Methods

##### `ProfileService:GetProfile(player)`
**Returns:** `profile, profileData`  
**Purpose:** Gets a player's profile and data

```lua
local profile, data = ProfileService:GetProfile(player)
if data then
    print(data.Coins)
end
```

##### `ProfileService:ChangeData(player, redirectories, newValue)`
**Parameters:**
- `player` - Player instance
- `redirectories` - Array of keys to navigate nested tables  
  Example: `{"Stats", "TotalPlayTime"}` → `data.Stats.TotalPlayTime`
- `newValue` - The new value to set

**Purpose:** Changes player data and automatically syncs to client

```lua
-- Change top-level data
ProfileService:ChangeData(player, {"Coins"}, 100)

-- Change nested data
ProfileService:ChangeData(player, {"Settings", "MusicVolume"}, 0.5)

-- Add item to inventory
local inventory = profile.Data.Inventory
table.insert(inventory, "Sword")
ProfileService:ChangeData(player, {"Inventory"}, inventory)
```

##### `ProfileService:WaitUntilProfileLoaded(player)`
**Purpose:** Yields until the player's profile is loaded

```lua
ProfileService:WaitUntilProfileLoaded(player)
local profile, data = ProfileService:GetProfile(player)
```

#### 4. Client Remote Signals

##### `ProfileService.Client.GetData`
- **Purpose:** Client requests their data
- **Flow:** Client fires → Server sends data back

##### `ProfileService.Client.UpdateSpecificData`
- **Purpose:** Server notifies client of data changes
- **Flow:** Server fires → Client updates local Data property
- **Note:** Reduces network traffic by sending only changed values

#### 5. Server Signals

##### `ProfileService.UpdateSpecificData`
**Purpose:** Server-side signal when data changes

```lua
ProfileService.UpdateSpecificData:Connect(function(player, redirectories, newValue)
    print(player.Name .. "'s data changed:", redirectories, newValue)
end)
```

#### 6. Client Methods (Called from client)

##### `ProfileService.Client:GetOtherPlayer_ProfileData(player, otherPlayer)`
**Purpose:** Get another player's data (for leaderboards, trading, etc.)  
**Returns:** otherPlayer's profileData

##### `ProfileService.Client:GetProfileAge(player)`
**Purpose:** Get how old the player's profile is in seconds  
**Returns:** number (seconds since profile creation)

### Data Flow
1. Player joins
2. `HandlePlayerAdded()` called
3. `ProfileStore:StartSessionAsync()` loads/creates profile
4. `Profile:Reconcile()` fills missing template fields
5. Profile stored in `Profiles[player]`
6. Client requests data via GetData signal
7. Server sends data to client
8. Profile auto-saves every 5 minutes
9. Player leaves → `profile:EndSession()` → final save

### Session Management
- Session locks prevent data loss from multiple servers
- If session can't be acquired, player is kicked
- `OnSessionEnd` fires if another server takes the session
- Auto-kick on session loss protects data integrity

---

## File 3: DataController.lua (CLIENT)

**Location:** `src/ReplicatedStorage/ClientSource/Client/DataController.lua`

### Purpose
Client-side Knit Controller that stores local copy of player data and provides methods to access it.

### Key Components

#### 1. Data Property
```lua
DataController.Data = nil
```
- Holds the local copy of player's data
- Updated when server sends data
- `nil` until first data load

#### 2. Key Methods

##### `DataController:GetPlayerData()`
**Returns:** `DataController.Data` (the local player's data)

```lua
local data = DataController:GetPlayerData()
if data then
    print("Coins:", data.Coins)
    print("Level:", data.Level)
end
```

##### `DataController:WaitUntilProfileLoaded()`
**Purpose:** Yields until data is loaded

```lua
DataController:WaitUntilProfileLoaded()
local data = DataController:GetPlayerData()
-- Data is guaranteed to be loaded here
```

##### `DataController:RequestToUpdateData()`
**Purpose:** Request fresh data from server  
**Note:** Usually not needed, data updates automatically

```lua
DataController:RequestToUpdateData()
```

#### 3. Auto-Update System
- `ProfileService.UpdateSpecificData` signal updates local data
- When server changes data, client automatically receives update
- Only changed values are sent (network optimization)
- Follows same redirectories path as `ChangeData()`

### Data Flow
1. `DataController:KnitStart()` runs
2. Connects to `ProfileService.GetData` signal
3. Requests data from server
4. Waits for data to load
5. Future updates auto-received via `UpdateSpecificData`

---

## Common Usage Patterns

### Pattern 1: Reading Player Data (Client)

```lua
-- In any client script
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataController = Knit.GetController("DataController")

DataController:WaitUntilProfileLoaded()
local data = DataController:GetPlayerData()

print("Player has", data.Coins, "coins")
print("Player level:", data.Level)
```

### Pattern 2: Modifying Player Data (Server)

```lua
-- In any server script
local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileService = Knit.GetService("ProfileService")

local function GiveCoins(player, amount)
    local profile, data = ProfileService:GetProfile(player)
    if not data then return end
    
    local newCoins = data.Coins + amount
    ProfileService:ChangeData(player, {"Coins"}, newCoins)
end

GiveCoins(player, 100)
```

### Pattern 3: Modifying Nested Data (Server)

```lua
local ProfileService = Knit.GetService("ProfileService")

local function ChangeVolume(player, volumeType, value)
    ProfileService:ChangeData(player, {"Settings", volumeType}, value)
end

ChangeVolume(player, "MusicVolume", 0.7)
```

### Pattern 4: Working with Tables (Server)

```lua
local ProfileService = Knit.GetService("ProfileService")

local function AddItemToInventory(player, itemName)
    local profile, data = ProfileService:GetProfile(player)
    if not data then return end
    
    -- Must create new table reference for ProfileService to detect change
    local newInventory = table.clone(data.Inventory)
    table.insert(newInventory, itemName)
    
    ProfileService:ChangeData(player, {"Inventory"}, newInventory)
end

AddItemToInventory(player, "Sword")
```

### Pattern 5: Listening to Data Changes (Client)

```lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileService = Knit.GetService("ProfileService")

-- Client can listen to specific data changes
ProfileService.UpdateSpecificData:Connect(function(redirectories, newValue)
    if redirectories[1] == "Coins" then
        print("Coins updated to:", newValue)
        -- Update UI here
    end
end)
```

### Pattern 6: Safe Data Access (Server)

```lua
local ProfileService = Knit.GetService("ProfileService")

-- Always check if profile exists
local function SafeDataOperation(player)
    local profile, data = ProfileService:GetProfile(player)
    if not profile then
        warn("Profile not found for " .. player.Name)
        return false
    end
    
    if not data then
        warn("Profile data is nil for " .. player.Name)
        return false
    end
    
    -- Safe to use data here
    return true
end
```

### Pattern 7: Listening to Data Changes (Server)

```lua
local ProfileService = Knit.GetService("ProfileService")

-- Server-side data change listener
ProfileService.UpdateSpecificData:Connect(function(player, redirectories, newValue)
    print(player.Name .. "'s data changed:")
    print("Path:", table.concat(redirectories, " -> "))
    print("New value:", newValue)
    
    -- Example: Check if coins changed
    if redirectories[1] == "Coins" then
        -- Do something when coins change
    end
end)
```

### Pattern 8: Getting Other Player's Data (Client)

```lua
local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileService = Knit.GetService("ProfileService")

-- Get another player's data (e.g., for leaderboard)
local function GetOtherPlayerCoins(otherPlayer)
    local otherData = ProfileService:GetOtherPlayer_ProfileData(otherPlayer)
    if otherData then
        return otherData.Coins
    end
    return 0
end
```

---

## Important Notes & Best Practices

### 1. Data Structure
- ✅ Always add new fields to ProfileTemplate
- ✅ `Profile:Reconcile()` fills missing fields automatically
- ✅ This ensures backward compatibility

### 2. Modifying Data
- ✅ **ALWAYS** use `ProfileService:ChangeData()` to modify data
- ❌ Never directly modify `profile.Data` without calling ChangeData
- ✅ ChangeData automatically syncs to client

### 3. Table Modifications
- ✅ When modifying tables (arrays/dictionaries), create new reference
- ✅ Use `table.clone()` or construct new table
- ❌ ProfileService won't detect in-place modifications

### 4. Client-Side
- ✅ Client data is **READ-ONLY**
- ✅ Use RemoteEvents/Functions to request server changes
- ❌ Never trust client data for important operations

### 5. Session Locking
- ✅ ProfileStore handles session locking automatically
- ✅ Player will be kicked if session can't be acquired
- ✅ Prevents data loss from server crashes

### 6. Auto-Saving
- ✅ Profiles auto-save every 5 minutes (default)
- ✅ Final save on player leave
- ✅ Can manually save with `profile:Save()`

### 7. Error Handling
- ✅ Always check if profile exists before accessing
- ✅ Use `ProfileService:WaitUntilProfileLoaded()` when needed
- ✅ Handle nil data gracefully

### 8. Performance
- ✅ UpdateSpecificData only sends changed values
- ✅ Reduces network traffic
- ✅ More efficient than sending entire data every time

### 9. Redirectories Parameter
- ✅ Array of string keys to navigate nested tables
- ✅ Example: `{"Settings", "MusicVolume"}` = `data.Settings.MusicVolume`
- ✅ Must create nested tables in ProfileTemplate first
- ❌ Will error if path doesn't exist

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **"Profile data not found for player"** | Wait for profile to load using `WaitUntilProfileLoaded()` |
| **Table changes not syncing to client** | Create new table reference, don't modify in-place<br>❌ BAD: `table.insert(data.Inventory, item)`<br>✅ GOOD: Create new table with `table.clone()` |
| **Client data is nil** | Call `DataController:WaitUntilProfileLoaded()` first |
| **"table does not exist" error** | Add the nested table structure to ProfileTemplate |
| **Data not saving** | Ensure player session is active (not kicked/left)<br>Check ProfileStore auto-save is working (5 min default) |

---

## Extending the System

### To Add New Data Fields:

**1. Add to ProfileTemplate.lua:**
```lua
ProfileTemplate = {
    NewField = defaultValue,
}
```

**2. Access on client:**
```lua
local data = DataController:GetPlayerData()
print(data.NewField)
```

**3. Modify on server:**
```lua
ProfileService:ChangeData(player, {"NewField"}, newValue)
```

**4. Existing profiles will auto-fill NewField on next load (Reconcile)**

---

## Summary for AI Context

When working with data in Superbullet project:

1. **DEFINE** data structure in `ProfileTemplate.lua`
2. **READ** data on client using `DataController:GetPlayerData()`
3. **MODIFY** data on server using `ProfileService:ChangeData()`
4. **LISTEN** to changes using `UpdateSpecificData` signals
5. **ALWAYS** check if profile/data exists before using
6. **USE** redirectories array for nested data: `{"Parent", "Child"}`
7. **CREATE** new table references when modifying tables
8. **WAIT** for profile load before accessing data

### The system handles:
- ✅ Automatic saving every 5 minutes
- ✅ Session locking across servers
- ✅ Client-server data synchronization
- ✅ Backward compatibility with Reconcile()
- ✅ GDPR compliance with AddUserId()

---

*End of Guide*

