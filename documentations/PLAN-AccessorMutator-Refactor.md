# Implementation Plan: Get() and Set() → Accessor and Mutator

> **Status: PLANNED**

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

### Files to Keep (Backward Compatibility)

| File | Status |
|------|--------|
| `TemplateService/Components/Get().lua` | Keep as-is (deprecated) |
| `TemplateService/Components/Set().lua` | Keep as-is (deprecated) |
| `TemplateController/Components/Get().lua` | Keep as-is (deprecated) |
| `TemplateController/Components/Set().lua` | Keep as-is (deprecated) |

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

- [ ] New `Accessor.lua` template loads correctly on server
- [ ] New `Mutator.lua` template loads correctly on server
- [ ] New `Accessor.lua` template loads correctly on client
- [ ] New `Mutator.lua` template loads correctly on client
- [ ] Old `Get().lua` still works if `Accessor.lua` doesn't exist
- [ ] Old `Set().lua` still works if `Mutator.lua` doesn't exist
- [ ] `service.Accessor` and `service.GetComponent` reference same module
- [ ] `service.Mutator` and `service.SetComponent` reference same module
- [ ] Existing projects using `GetComponent`/`SetComponent` work without changes

---

## File Structure After Implementation

```
Components/
├── Accessor.lua      (NEW - recommended)
├── Mutator.lua       (NEW - recommended)
├── Get().lua         (KEPT - deprecated, backward compat)
├── Set().lua         (KEPT - deprecated, backward compat)
└── [other components...]
```

---

## Summary

| Task | Complexity |
|------|------------|
| Create 4 new template files | Low |
| Update KnitServer.lua loading logic | Medium |
| Update KnitClient.lua loading logic | Medium |
| Update README.md | Low |
| Testing | Medium |

**Total estimated changes:** ~50 lines of code across 6 files
