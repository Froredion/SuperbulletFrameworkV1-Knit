# Implementation Plan: Get() and Set() → Accessor and Mutator

> **Status: IMPLEMENTED ✅**

## Overview

Rename component utility methods from `Get()` and `Set()` to `Accessor` and `Mutator` for improved clarity while maintaining full backward compatibility.

## New API

```lua
-- New API (recommended)
service.Accessor    -- for reading/fetching data
service.Mutator     -- for modifying/updating data

-- Backward compatibility (deprecated but still works)
service.GetComponent  -- alias → points to Accessor
service.SetComponent  -- alias → points to Mutator
```

---

## Scope Analysis

### Files to Modify

| File | Change Type |
|------|-------------|
| `KnitServer.lua` | Add Accessor/Mutator loading + keep Get/Set aliases |
| `KnitClient.lua` | Add Accessor/Mutator loading + keep Get/Set aliases |

### Files to Create

| File | Purpose |
|------|---------|
| `TemplateService/Components/Accessor.lua` | New accessor component template |
| `TemplateService/Components/Mutator.lua` | New mutator component template |
| `TemplateController/Components/Accessor.lua` | New accessor component template |
| `TemplateController/Components/Mutator.lua` | New mutator component template |

### Files Removed (No Longer Needed)

| File | Status |
|------|--------|
| `TemplateService/Components/Get().lua` | ❌ Removed |
| `TemplateService/Components/Set().lua` | ❌ Removed |
| `TemplateController/Components/Get().lua` | ❌ Removed |
| `TemplateController/Components/Set().lua` | ❌ Removed |

> Note: Backward compatibility is still maintained via the Knit loading logic which falls back to `Get()`/`Set()` if `Accessor`/`Mutator` don't exist.

---

## Implementation Steps

### Step 1: Create New Accessor/Mutator Component Templates

Create `Accessor.lua` and `Mutator.lua` files as the new standard templates:

**Server-side:**
- `src/ServerScriptService/ServerSource/Server/TemplateService/Components/Accessor.lua`
- `src/ServerScriptService/ServerSource/Server/TemplateService/Components/Mutator.lua`

**Client-side:**
- `src/ReplicatedStorage/ClientSource/Client/TemplateController/Components/Accessor.lua`
- `src/ReplicatedStorage/ClientSource/Client/TemplateController/Components/Mutator.lua`

### Step 2: Update KnitServer.lua

**Location:** `src/ReplicatedStorage/Packages/_Index/superbullet_knit@0.0.1/knit/KnitServer.lua`

**Current code (lines 176-188):**
```lua
-- Get and Set components
local getComponent = componentsFolder:WaitForChild("Get()", 1)
if getComponent and getComponent:IsA("ModuleScript") then
    serviceOrController.GetComponent = require(getComponent)
end

local setComponent = componentsFolder:WaitForChild("Set()", 1)
if setComponent and setComponent:IsA("ModuleScript") then
    serviceOrController.SetComponent = require(setComponent)
end
```

**New code:**
```lua
-- Accessor component (new naming) with Get() fallback for backward compatibility
local accessorComponent = componentsFolder:FindFirstChild("Accessor")
if not accessorComponent then
    accessorComponent = componentsFolder:WaitForChild("Get()", 1) -- Backward compatibility
end
if accessorComponent and accessorComponent:IsA("ModuleScript") then
    serviceOrController.Accessor = require(accessorComponent)
    serviceOrController.GetComponent = serviceOrController.Accessor -- Alias for backward compatibility
end

-- Mutator component (new naming) with Set() fallback for backward compatibility
local mutatorComponent = componentsFolder:FindFirstChild("Mutator")
if not mutatorComponent then
    mutatorComponent = componentsFolder:WaitForChild("Set()", 1) -- Backward compatibility
end
if mutatorComponent and mutatorComponent:IsA("ModuleScript") then
    serviceOrController.Mutator = require(mutatorComponent)
    serviceOrController.SetComponent = serviceOrController.Mutator -- Alias for backward compatibility
end
```

### Step 3: Update KnitClient.lua

**Location:** `src/ReplicatedStorage/Packages/_Index/superbullet_knit@0.0.1/knit/KnitClient.lua`

Apply the same pattern as KnitServer.lua (lines 155-167).

### Step 4: Update README.md

Move the "Next Major Update" section to a "Recent Updates" or changelog section indicating this is now implemented.

---

## Backward Compatibility Strategy

### API Surface

| Old API | New API | Behavior |
|---------|---------|----------|
| `service.GetComponent` | `service.Accessor` | Both work, same reference |
| `service.SetComponent` | `service.Mutator` | Both work, same reference |
| `Get().lua` file | `Accessor.lua` file | Either works, new preferred |
| `Set().lua` file | `Mutator.lua` file | Either works, new preferred |

### Priority Order

1. Look for `Accessor.lua` / `Mutator.lua` first (new naming)
2. Fall back to `Get().lua` / `Set().lua` if not found (old naming)
3. Expose both aliases (`Accessor`/`GetComponent`, `Mutator`/`SetComponent`)

### Deprecation Notice

Add deprecation warnings in a future version (optional):
```lua
-- In future versions, add:
warn("[Knit] GetComponent is deprecated, use Accessor instead")
warn("[Knit] SetComponent is deprecated, use Mutator instead")
```

---

## Testing Checklist

- [x] New `Accessor.lua` template loads correctly on server
- [x] New `Mutator.lua` template loads correctly on server
- [x] New `Accessor.lua` template loads correctly on client
- [x] New `Mutator.lua` template loads correctly on client
- [x] Old `Get().lua` still works if `Accessor.lua` doesn't exist (via fallback logic)
- [x] Old `Set().lua` still works if `Mutator.lua` doesn't exist (via fallback logic)
- [x] `service.Accessor` and `service.GetComponent` reference same module
- [x] `service.Mutator` and `service.SetComponent` reference same module
- [x] Existing projects using `GetComponent`/`SetComponent` work without changes

---

## File Structure After Implementation

```
Components/
├── Accessor.lua      (NEW - standard)
├── Mutator.lua       (NEW - standard)
├── Others/           (folder for other component modules)
└── [other components...]
```

> Note: `Get().lua` and `Set().lua` have been removed from the template. Backward compatibility is maintained through the Knit loading logic.

---

## Summary

| Task | Status |
|------|--------|
| Create 4 new template files | ✅ Done |
| Update KnitServer.lua loading logic | ✅ Done |
| Update KnitClient.lua loading logic | ✅ Done |
| Update README.md | ✅ Done |
| Remove deprecated Get()/Set() files | ✅ Done |

**Implementation complete.** All changes have been applied and tested.
