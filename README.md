# SuperbulletFrameworkV1-Knit

_A clean, opinionated wrapper over Knit with beginner-friendly error handling, and structure_

---

## Why Knit? Why a Wrapper?

Many Roblox developers struggle to keep large projects organized. Out of the box, Roblox scripts can quickly get messy:

- No clear separation between systems
- Hard-to-trace errors that overwhelm beginners
- Risk of cyclical dependencies between scripts

[Knit](https://github.com/Sleitnick/Knit) is a lightweight framework that solves a lot of these problems. It’s MIT-licensed and widely adopted framework in the Roblox dev community.
Ever wonder how top developers release a game in just 7–14 days? The problem isn’t your skills, it’s how the best Roblox developers structure and organize their code

But… Knit itself is not always beginner-friendly:

- Errors often show **giant stacktraces** full of Promise chains
- Misusing `:GetService()` gives cryptic logs
- New scripters get lost in the lifecycle order

**SuperbulletFrameworkV1-Knit** is a Roblox server framework built on top of [Sleitnick's Knit](https://github.com/Sleitnick/Knit), with these goals:

- ✅ Beginner-friendly error logs for `:KnitInit()` and service startup
- ✅ Clear separation of subsystems and public methods to reduce cyclical dependencies
- ✅ IntelliSense support for component source files
- ✅ Built with modular, scalable OOP-first design in mind

---

## Before vs After: `:KnitInit()` Error Hell

### ❌ **The Old Way** – Huge stacktrace, impossible to read:

```
01:21:09.654  -- Promise.Error(ExecutionError) --

The Promise at:
ReplicatedStorage.Packages._Index.sleitnick_knit@1.7.0.knit.KnitServer:405 function Start
ServerScriptService.KnitServer:14

...Rejected because it was chained to the following Promise, which encountered an error:

ServerScriptService.ServerSource.Server.LevelService:132: attempt to index nil with 'SomeMethod'
...
```

### ✅ **The New Way** – Clean and readable:

```
━━━━━━━━━━━━━━━━━━━
❌ KnitInit Error in Service: LevelService
━━━━━━━━━━━━━━━━━━━━
Error: ServerScriptService.ServerSource.Server.LevelService:132: attempt to index nil with 'SomeMethod'
━━━━━━━━━━━━━━━━━━━
```

Now even beginner scripters can instantly understand which service and line number broke without digging through chained Promises or Promise creation metadata.

---

## Clean Logging for `:GetService()` Misuse

### ❌ Default Knit Error (hard to trace for beginners):

```
ReplicatedStorage.Packages._Index.sleitnick_knit@1.7.0.knit.KnitServer:252: Cannot call GetService until Knit has been started
```

### ✅ New Beginner-Friendly Log:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ Cannot call GetService until Knit has been started
━━━━━━━━━━━━━━━━━━━━━━━━━━━
You are calling this from a Script.
Solution: Use Knit.OnStart():await() to wait for Knit to start

Example:
  Knit.OnStart():await()
  local MyService = Knit.GetService("MyService")
━━━━━━━━━━━━━━━━━━━━━━━━━━━  -  Server - KnitServer:252
```

💡 Perfect for teams onboarding new developers or self-taught beginners still wrapping their heads around lifecycle methods.

Battle‑tested across ModuleScripts, Scripts, LocalScripts, and Knit Controllers/Services.

---

## Design Philosophy: Built for Beginners First

### Why We Chose Knit: It Solves Cyclical Dependencies

One of the biggest problems beginners face is **cyclical dependencies** — when two modules try to require each other, causing confusing errors that leave developers stuck.

**Why this matters:**

- New developers don't understand how to connect 2 different modules safely
- Cyclical dependency errors are cryptic and frustrating
- This single issue stops beginners from progressing

**Knit solves this problem** through its service-based architecture, where services can safely reference each other through `GetService()` without creating circular requires.

**That's why we chose to stick with Knit** — it fundamentally solves the connection problem that confuses beginners, and we built on top of it to make it even more accessible with:

- Clearer error messages that teach, not just report
- Component-based architecture that's easy to understand
- Better separation of concerns to avoid common pitfalls

### Not Perfect — But Perfect for Beginners

**SuperbulletFrameworkV1-Knit** is intentionally designed as **the perfect framework for beginners**, not the "perfect" framework overall.

We made specific trade-offs:

- ✅ **Clarity over elegance** — verbose but understandable
- ✅ **Error messages that teach** — not just report
- ✅ **Familiar patterns** — OOP that feels natural
- ✅ **Backward compatibility** — works with existing Knit knowledge

### What About Advanced Developers?

If you need the cleanest, most performant, industry-standard architecture, stay tuned for:

🚀 **SuperbulletFrameworkV1-ECS** — Our upcoming framework built on [JECS](https://github.com/Ukendio/jecs)

ECS (Entity Component System) is the **industry standard** for game architecture. It's what we'll recommend for production games and experienced teams.

But for **learning, prototyping, and small-to-medium projects**, this Knit-based framework gets you building fast without the learning curve of ECS.

---

## Architecture Notes

- Most subsystems live in their own folders/modules and **only** use Knit to expose public methods.
- **I only ever use Knit as a parent system** — its role is to **expose public methods and group multiple subsystems** for better project structure and avoid cluttered dependency trees.
- This avoids Knit's cyclical dependency pitfalls and supports better **OOP layering**.
- All services support `:KnitInit()` and `:KnitStart()` overrides, with enhanced logging built-in.
- Intellisense is supported on most core component files for fast iteration and DX.
- It's far from being perfect!!

---

## Solving "Framework Baggage"

One of the issues [mentioned in Knit's retrospective](https://medium.com/@sleitnick/knit-its-history-and-how-to-build-it-better-3100da97b36) is **framework baggage** — the overhead and complexity that comes with adopting a framework.

### How We Address This

**SuperbulletFrameworkV1-Knit** solves this through a **component-based architecture** that uses standard `require()`:

```lua
-- Components are just regular ModuleScripts
local Template = require(script.Components.Others.Template)

-- No special framework magic needed — just plain Lua
local myInstance = Template.new()
```

**Knit is only used as a parent system** to expose public methods and organize services — your actual logic lives in portable, framework-agnostic components.

📖 **Learn more about our project structure philosophy:**  
[Organizing Project Structure - Superbullet Docs](https://docs.superbulletstudios.com/prompt-engineering/organizing-project-structure)

---

## ⬇️ Download & Access

You can try **SuperbulletFrameworkV1-Knit** in three ways:

1. **Via Superbullet Application**
   Best experience — fully integrated with **SuperbulletAI**, error-handling, and template sync. It'll implement it for you automatically.
   👉 [Download Superbullet](https://ai.superbulletstudios.com/)

2. **From GitHub**
   For developers who want direct source access and manual setup.
   👉 [GitHub Repository](https://github.com/SuperbulletStudios/SuperbulletFrameworkV1-Knit)

3. **Roblox Place File**
   Quick start inside Roblox Studio. Import and explore immediately.
   👉 `SuperbulletFrameworkV1-Knit.rbxl` of this repositoroy.

⚡ Pick whichever fits your workflow — the **Superbullet App** is the easiest, while **GitHub + Roblox Place** give you raw access for tinkering.

---

## Designed for SuperbulletAI

One of the biggest reasons this framework exists is to pair **perfectly** with **SuperbulletAI** and how we've been coding for years ever since Knit released.

> **If an error occurs, SuperbulletAI can detect it and fix it in one edit.**

This framework is built to guide you—not confuse you—so the AI can:

- Instantly recognize what went wrong
- Propose and apply a fix
- Help beginners start fast with no frustration

It’s more than a framework—it's a launchpad.

---

## What's Next?

### ✅ Automated Component Initializers - DONE!

Component initialization is now automated! No more boilerplate for loading your components.

### 🎯 Intellisense Improvements

According to [this article](https://medium.com/@sleitnick/knit-its-history-and-how-to-build-it-better-3100da97b36), Knit's biggest problem has always been **intellisense support**.

**We've mostly solved it!** 🎉

```lua
-- Now you can get the exact script instance:
local TemplateServiceInstance = Knit.GetService("TemplateService").Instance

-- Then require it for full intellisense:
local TemplateService = require(Knit.GetService("TemplateService").Instance)
```

✅ **What works**: `.Instance` property returns the exact ModuleScript, giving you full type checking and autocomplete for all methods/components.

⚠️ **What's left**: You still need to manually `require()` the instance. But if you know how to use `.Instance`, you should know how to `require` — so we kept it simple and didn't automate this step.

### 🔧 Remaining Issue

**Autocomplete for service names** — When typing `Knit.GetService("Te`, the IDE should suggest `TemplateService`. This is an easy fix and will be addressed in a future update.

### 🧩 Backward Compatibility

**SuperbulletFrameworkV1-Knit** isn't perfect or as clean as it could be yet. We're prioritizing **backward compatibility with vanilla Knit** to keep this framework accessible to everyone — whether you're migrating an existing project or starting fresh.

### 🔤 Next Major Update: Method Naming Improvement

**Get() and Set() → Accessor and Mutator**

In the next update, we'll be renaming `Get()` and `Set()` to **`Accessor`** and **`Mutator`** to better explain what they do in a straightforward way.

- `Get()` → `Accessor` — clearly indicates it's for accessing/reading data
- `Set()` → `Mutator` — clearly indicates it's for mutating/modifying data

**Backward compatibility will be maintained** so your existing code using `Get()` and `Set()` will continue to work. This change is all about improving clarity for new developers while keeping your current projects running smoothly.

### 🚀 Future Plans

1. 🔄 Full ECS-based rewrite: `SuperbulletFrameworkV1-ECS` built on [JECS](hhttps://github.com/Ukendio/jecs)
2. 🔍 Service name autocomplete in `Knit.GetService()`
3. 📦 More template utilities and helpers

---

## 📦 License

Base framework is built over **[Knit (MIT)](https://github.com/Sleitnick/Knit/blob/main/LICENSE)**.
SuperbulletV1-Knit extensions are MIT-like as well, it's built literally for SuperbulletAI.

---

### 💬 Community-Driven Improvements

We've addressed the core issues, but **we need your input!**

If you have ideas for improving SuperbulletFrameworkV1-Knit or making it more accessible, please share your feedback. This framework is built for the community, and your suggestions will shape its future.

## 🤝 Contribute / Feedback?

Got ideas, feature requests, or want to contribute?

Reply here or message me on DevForum or [Discord].
Let’s push Roblox frameworks forward—cleaner, smarter, faster. 🔥
