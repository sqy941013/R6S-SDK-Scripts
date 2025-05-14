# HeatedMetal API 文档与功能实现指南 (v2)

欢迎使用 HeatedMetal API！本文档旨在帮助您理解如何使用 Squirrel 脚本语言与 HeatedMetal 游戏引擎进行交互，以实现自定义游戏逻辑、功能模块或工具。

## 目录

- [1. 简介](#1-简介)
  - [什么是 HeatedMetal API?](#什么是-heatedmetal-api)
  - [Squirrel 脚本语言](#squirrel-脚本语言)
  - [模块系统 (Module System)](#模块系统-module-system)
- [2. 核心概念](#2-核心概念)
  - [回调函数 (Callbacks)](#回调函数-callbacks)
  - [对象ID (Object IDs)](#对象id-object-ids)
  - [客户端 vs. 服务器端](#客户端-vs-服务器端)
  - [核心枚举 (Core Enums)](#核心枚举-core-enums)
- [3. API 参考](#3-api-参考)
  - [全局函数与工具](#全局函数与工具)
  - [数学类](#数学类)
  - [工具类](#工具类)
  - [渲染器 API (Renderer)](#渲染器-api-renderer)
  - [游戏 API (Game)](#游戏-api-game)
    - [实体 (Game.Entity)](#实体-gameentity)
    - [组件 (Game.Component, Game.DamageComponent, Game.WeaponComponent)](#组件-gamecomponent-gamedamagecomponent-gameweaponcomponent)
    - [玩家控制器 (Game.PlayerController)](#玩家控制器-gameplayercontroller)
    - [世界与游戏状态](#世界与游戏状态)
    - [游戏机制](#游戏机制)
  - [回调函数列表](#回调函数列表)
- [4. 如何实现特定功能 (示例)](#4-如何实现特定功能-示例)
  - [示例 1: 在屏幕上显示玩家生命值](#示例-1-在屏幕上显示玩家生命值)
  - [示例 2: 创建自定义命令给予玩家武器](#示例-2-创建自定义命令给予玩家武器)
  - [示例 3: 使实体在死亡时爆炸](#示例-3-使实体在死亡时爆炸)
  - [示例 4: 修改武器属性](#示例-4-修改武器属性)
  - [示例 5: 绘制自定义UI元素 (如准星)](#示例-5-绘制自定义ui元素-如准星)
  - [示例 6: 传送玩家](#示例-6-传送玩家)
  - [示例 7: 通过网络发送和接收数据](#示例-7-通过网络发送和接收数据)
  - [示例 8: 实体轮廓高亮](#示例-8-实体轮廓高亮)
  - [示例 9: 复杂场景控制 (如电梯)](#示例-9-复杂场景控制-如电梯)
- [5. 重要注意事项与最佳实践](#5-重要注意事项与最佳实践)
  - [脚本结构](#脚本结构)

## 1. 简介

### 什么是 HeatedMetal API?

HeatedMetal API 提供了一系列接口，允许开发者通过 Squirrel 脚本语言扩展和修改 HeatedMetal 游戏的行为。您可以创建新的游戏模式、自定义玩家交互、修改实体属性、渲染自定义图形等等。

### Squirrel 脚本语言

所有与 HeatedMetal API 的交互都通过 Squirrel 进行。Squirrel 是一种轻量级、面向对象的脚本语言，语法类似于 C++/Java/C#。您需要对 Squirrel 的基本语法和概念有所了解才能有效使用此 API。

- 官方文档: https://quirrel.io/doc/reference/language.html

### 模块系统 (Module System)

HeatedMetal 的 Squirrel 环境支持模块系统，允许您组织代码并将功能封装到不同的文件中。

- 使用 `require("ModuleName")` 函数来加载模块。

- 您可以从模块中导入特定的对象或整个模块。例如，要使用核心游戏 API，通常会这样做：

```squirrel
local { Game } = require("HeatedMetal"); // 从 "HeatedMetal" 模块中导入 Game 对象
local math = require("math"); // 导入标准的 "math" 模块
```

- 之后，您就可以通过 `Game.SomeFunction()` 或 `math.sin()` 来调用相应的功能。

## 2. 核心概念

### 回调函数 (Callbacks)

API 的核心是事件驱动的。您可以通过 `AddCallback_` 系列函数注册自己的 Squirrel 函数，当特定的游戏事件发生时（例如玩家死亡、回合开始、每帧更新），您注册的函数就会被调用。

**重要**:

- `AddCallback_RoundStart` 回调会在世界重新加载后保留。

- 所有其他回调函数在世界重新加载时会被清除，需要重新注册。

### 对象ID (Object IDs)

游戏中的许多对象（如实体、组件、玩家、地图元素等）都通过一个唯一的 `uint64 ObjectID` 来标识。API 中的许多函数会返回或接受这些 ID。在编写脚本时，您可能会使用预定义的 ObjectID 来引用特定的地图资产或物品。

### 客户端 vs. 服务器端

某些 API 功能可能仅在客户端或服务器端可用/有效。

- **客户端**: 通常处理与本地玩家、UI 渲染相关的逻辑。

- **服务器端 (主机)**: 通常处理游戏规则、实体状态同步、命令执行等。

文档中会尽可能标明特定函数的适用范围。例如，`IsKeyPressed` 通常是客户端函数，而武器属性的修改或实体生成通常应在主机端进行才能同步给所有玩家。`Game.IsHost()` 函数可用于判断当前脚本是否在主机上运行。

### 核心枚举 (Core Enums)

游戏中广泛使用的常量（如地图标识、队伍、物品类型、伤害类型等）通常被定义为枚举类型。这些枚举可能位于核心模块中，例如 `HeatedMetal/Modules/Core/enums.nut`。

- 一旦核心模块被游戏加载，这些枚举值（如示例中使用的 `eMap.Tower`）通常可以直接在脚本中使用，无需显式导入该枚举文件。

- 熟悉这些核心枚举对于编写与游戏状态和特定内容相关的逻辑至关重要。

## 3. API 参考

以下是 API 主要部分的摘要。详细信息请参考头文件 `HeatedMetal/QuirrelDoc.h` 中的注释。

### 全局函数与工具

- `void Yield()`: 暂停当前脚本的执行，允许其他脚本或游戏主循环运行。在耗时循环中使用以避免游戏卡顿。

- `bool Sleep(uint32 MilliSeconds)`: 暂停脚本执行指定的毫秒数。

- `bool IsKeyPressed(string KeyName)`: (客户端) 检查指定按键当前是否被按下。

- `bool RegisterCommand(function Func, string Name, string Arguments, string Description)`: 注册一个控制台命令。
  - `Func`: 命令触发时调用的 Squirrel 函数。
  - `Name`: 命令的名称 (例如 "mycommand")。
  - `Arguments`: 命令参数的描述 (例如 "<player_name> ")。
  - `Description`: 命令的简短描述。

- `string HMVersion()`: 返回 HeatedMetal 版本字符串。

- `uint32 HMVersionInt()`: 返回 HeatedMetal 版本整数。

- `float DeltaTime()`: 返回上一帧到当前帧的时间差 (秒)，用于实现帧率无关的逻辑。

- `float RandomFloat(float Max)` / `RandomFloatRange(float Min, float Max)`: 生成随机浮点数。

- `int64 RandomInt(int64 Max)` / `RandomIntRange(int64 Min, int64 Max)`: 生成随机整数。

- `void SendNetworkTable(string Name, table Table, PlayerController Receiver = null)`: 通过网络发送一个 Squirrel 表。
  - `Name`: 表的名称，用于接收端回调识别。
  - `Table`: 要发送的 Squirrel 表 (可包含 bool, int, float, string, Vector 等基础类型)。
  - `Receiver`: (服务器可选) 指定接收该表的玩家，如果为 null 或未提供，则广播给所有客户端 (如果从服务器发送) 或发送给服务器 (如果从客户端发送)。

### 数学类

这些类用于处理游戏中的几何和颜色数据。

- `Vector2(float x, float y)`: 2D 向量。
  - `Length()`, `LengthSq()`, `Normalize()`, `Dot(Vector2 Other)`

- `Vector3(float x, float y, float z)`: 3D 向量。
  - `Length()`, `LengthSq()`, `Normalize()`, `Dot(Vector3 Other)`, `Cross(Vector3 Other)`, `ToVec4()`, `ToQuat()`, `Round(float Precision)`

- `Vector4(float x, float y, float z, float w)`: 4D 向量 (常用于齐次坐标或颜色)。
  - `Length()`, `LengthSq()`, `Normalize()`, `Dot(Vector4 Other)`, `Distance(Vector4 Other)`, `ToVec3()`, `ToQuat()`

- `Quaternion(float x, float y, float z, float w)`: 四元数，用于表示旋转。
  - `Rotate(Vector3 Input)`, `Conjugate()`, `Inverse()`, `Normalize()`, `ToVec3()`, `ToVec4()`

- `Color(float R, float G, float B, float A)`: 颜色 (RGBA, 值通常在 0.0 到 1.0)。
  - `static Color RGB(float R, float G, float B, float A)`: 从 0-255 RGB 转换。
  - `Invert()`, `Fade(Color To, float Factor)`
  - `static Color Random()`, `static Color RandomS(uint32 Seed)`, `static Color Rainbow(float Speed)`

### 工具类

- `Timer(bool StartNow)`: 计时器。
  - `Start()`: 启动或重新启动计时器。
  - `Reset()`: 重置计时器，但不停止它（如果正在运行）。通常用于重新计算 ElapsedTime 的起点。
  - `float ElapsedTime()`: 获取从上次 Start() 或 Reset() 到现在经过的时间（秒）。
  - `bool HasElapsed(float time)`: 检查是否已经过去了指定的时间（秒）。

- `Pointer`: **极度危险，谨慎使用！** 用于直接读写内存地址。
  - 提供 `GetBool`, `SetBool`, `GetInt32`, `SetFloat`, `GetVector3`, `SetVector3` 等一系列方法，通过内存偏移量操作数据。
  - `Pointer* Read(uint64 offset)`: 读取一个指针。

### 渲染器 API (Renderer)

用于在屏幕上绘制 2D 和 3D 图形。通常在 `AddCallback_Update` 中使用。

- `Vector2 GetDisplaySize()`: 获取屏幕/窗口尺寸。

- `float DistanceToAlpha(float Distance, float MaxDistance, float MinAlpha = 25.0, float MaxAlpha = 255.0)`: 根据距离计算透明度。

- **3D 绘制**:
  - `Text(string Text, Vector3 Origin, Color Color)`
  - `Line(Vector3 StartOrigin, Vector3 EndOrigin, Color Color, float Thickness)`
  - `Rectangle(Vector3 Origin, Vector3 Angles, float Width, float Height, Color Color, float Thickness)`
  - `Circle(Vector3 Origin, Vector3 Angles, float Radius, int NumSegments, Color Color, float Thickness)`
  - `Cylinder(Vector3 Origin, Vector3 Angles, float Radius, float Height, int NumSegments, Color Color, float Thickness)`
  - `Sphere(Vector3 Origin, Vector3 Angles, float Radius, int NumSegments, Color Color, float Thickness)`
  - `Cube(Vector3 Origin, Vector3 Angles, float Size, Color Color, float Thickness)`

- **2D 绘制**:
  - `Text2D(string Text, Vector2 ScreenPos, Color Color)`
  - `Line2D(Vector2 Start, Vector2 End, Color Color, float Thickness)`
  - `Circle2D(Vector2 ScreenPos, Color Color, float Radius, int NumSegments, float Thickness)`

### 游戏 API (Game)

这是与核心游戏逻辑交互的主要接口，通过 `require("HeatedMetal")` 获取的 Game 对象访问。

#### 实体 (Game.Entity)

代表游戏世界中的对象。

- `string Name()`: 获取实体名称。

- `Vector3 GetOrigin()` / `void SetOrigin(Vector3 Origin)`: 获取/设置实体世界坐标。

- `Vector3 GetCenter()`: 获取实体中心点坐标。

- `Vector3 GetAngles()` / `void SetAngles(Vector3 Angles)`: 获取/设置实体旋转。

- `Vector3 GetScale()` / `void SetScale(Vector3 Scale)`: 获取/设置实体缩放。

- `Vector3 GetRight()` / `GetForward()` / `GetUp()`: 获取实体局部坐标轴方向。

- `Vector3 GetBoneOrigin(uint32 Bone)`: 获取骨骼世界坐标 (骨骼枚举 eBone 在核心模块)。

- `void SetOutline(Color Color)`: (客户端) 设置实体轮廓线。

- `Entity* Duplicate()`: 创建此实体的副本。**重要**: 复制的实体默认不在世界中，需要调用 `AddToWorld()`。

- `bool AddToWorld()`: 将实体添加到世界中，使其可见和可交互。

- `bool RemoveFromWorld()`: 从世界中移除实体。如果是复制的实体，这通常意味着销毁它。

- `bool GetActive()` / `void SetActive(bool IsActive)`: 获取/设置实体及其所有组件的激活状态。

- `void SetIsHidden(bool IsHidden)`: 隐藏实体视觉效果。

- `DamageComponent* DamageComponent()`: 获取伤害组件。

- `WeaponComponent* WeaponComponent()`: 获取武器组件 (仅主机端，5秒更新一次)。

- `Component* DestructionComponent()`: 获取破坏组件。

#### 组件 (Game.Component, Game.DamageComponent, Game.WeaponComponent)

实体功能的模块化部分。

- **Game.Component (基类)**:
  - `Entity* Entity()`: 获取所属实体。
  - `bool GetActive()` / `void SetActive(bool Active)`: 获取/设置组件激活状态。

- **Game.DamageComponent**:
  - `int32 GetHealth()` / `void SetHealth(int32 Health)`
  - `int32 GetMaxHealth()` / `void SetMaxHealth(uint32 MaxHealth)`

- **Game.WeaponComponent**:
  - 包含 `DamageWeaponData`, `AmmoWeaponData`, `AccuracyWeaponData`, `AnimationWeaponData` 等子类用于访问详细武器参数。
    - 例如: `weaponComp.GetAmmoData().SetFireRate(1000)`
  - `uint32 GetAmmo()` / `void SetAmmo(uint32 Value)`: 获取/设置当前弹匣弹药。
  - `bool IsReloading()`: 是否在换弹。
  - `string Name()`: 武器数据名。

#### 玩家控制器 (Game.PlayerController)

代表游戏中的玩家。

- `string Name()`: 玩家名。

- `Team Team()`: 玩家队伍 (`enum Team { A, B, Spectator, Invalid }`)。

- `Entity* Entity()`: 获取玩家控制的实体。

- `void SetOrigin(Vector3 Origin)`: 设置玩家实体位置 (传送)。

- `WeaponComponent* Weapon()`: 获取当前持有武器组件。

- `DamageComponent* Damage()`: 获取玩家伤害组件。

- `enum ItemSlot { Primary, Secondary, ..., Character }`: 物品槽位。

- `void SetItemSlot(ItemSlot Slot, uint64 ObjectID)`: 设置指定槽位的物品。

- `uint64 PrimaryID()` / `SecondaryID()` / `CharacterID()` 等: 获取各槽位物品ObjectID。

#### 世界与游戏状态

- `Game.VolumetricFog GetVolumetricFog()`: (客户端) 获取体积雾设置。
  - `IsEnabled()`, `SetDensity(float Density)`, `SetTop(float Top)` 等。

- `Game.Skylight GetSkylight()`: (客户端) 获取天空光设置。
  - `SetSunIntensity(float Intensity)`, `SetSunRotation(float Rotation)` 等。

- `bool IsTimerPaused()` / `void SetTimerPaused(bool IsPaused)`: 游戏阶段计时器。

- `float GetTimerRemaining()` / `void SetTimerRemaining(int32 TimeInSeconds)`: 计时器剩余时间。

- `bool IsHost()`: 是否为主机。

- `PlayerController* GetLocalPlayer()`: 获取本地玩家控制器。

- `Array<PlayerController*> GetPlayerList()`: 获取所有玩家列表。

- `Array<Entity*> GetAIList()`: 获取所有AI实体列表。

- `View* GetCamera()`: (客户端) 获取当前摄像机/视角信息。
  - `Origin()`, `Forward()`, `Fov()`

- `uint64 GetWorld()` / `GetGameMode()` / `GetGameState()`: 获取当前世界、游戏模式、游戏状态的ID或值。

- `Entity* GetEntity(uint64 ObjectID)`: 通过ID获取实体实例。如果实体不存在，返回 null。

- `Entity* CreateExternalEntity(uint64 ObjectID)`: 从外部预加载数据创建一个实体副本。

- `Pointer* GetObject(uint64 ObjectID)`: **危险!** 通过ID获取对象的原始指针包装器。

#### 游戏机制

- `void CreateDust(Vector3 Origin, float Radius, Color Color)`: 创建尘埃粒子。

- `void CreateExplosion(Vector3 Origin, ExplosionType Type, PlayerController Owner = null)`: 创建爆炸效果。
  - `ExplosionType` 是一个枚举，包含多种爆炸类型。

- `RaycastResult Raycast(Vector3 Start, Vector3 End, uint8 Count)`: 执行射线检测。
  - `RaycastResult.DidHit()`: 是否命中。
  - `RaycastResult.Hits()`: 返回 `Array<CastHit>`，包含命中信息 (`Origin()`, `Normal()`, `Entity()`)。

### 回调函数列表

以下是可以通过 `AddCallback_` 前缀注册的事件回调：

- `Shutdown`: 模块关闭时。

- `Update`: 每游戏逻辑帧。

- `RoundStart (ObjectID WorldID)`: 回合开始。

- `BulletHit (Vector3 Start, Vector3 End, Vector3 Normal, float Delta, Entity HitEntity)`: 子弹击中时。

- `Damage (DamageComponent HitDamageComp, uint32 TakenDamage, uint32 DamageType, PlayerController Attacker, PlayerController Victim)`: 造成伤害时。

- `EntityEffect (Entity Instigator, Entity Source, uint32 EffectType)`: 实体效果产生时。

- `NetworkTable (string TableName, table ReceivedTable, PlayerController Sender)`: 接收到网络表时。

- `WeaponZoomIn (WeaponComponent Weapon)` / `WeaponZoomOut`: 武器瞄准/取消瞄准。

- `WeaponFire (WeaponComponent Weapon)` / `WeaponFireStop`: 武器开火/停止开火。

- `PlayerDeath (PlayerController Player)`: 玩家死亡。

- `PlayerSpawn (PlayerController Player)`: 玩家出生/重生。

- `LeanRight (PlayerController Player)` / `LeanLeft`: 玩家左/右倾。

- `Crouch (PlayerController Player)` / `Prone`: 玩家蹲伏/卧倒。

- `Melee (PlayerController Player)`: 玩家近战。

- `Interact (PlayerController Player)`: 玩家交互。

- `AccessDrone (PlayerController Player)`: 玩家使用无人机。

- `Ping (PlayerController Player)`: 玩家标记。

- `DefuserDeployed (PlayerController Instigator, uint32 Alliance, Entity Bomb)`: 拆弹器部署。

- `DefuserSabotaged (PlayerController Instigator, uint32 Alliance)`: 拆弹器被破坏。

- `DefuserSucceded (PlayerController Instigator, uint32 Alliance, Entity Bomb)`: 拆弹成功。

- `DefuserDropped (PlayerController Instigator)` / `DefuserPickedUp`: 拆弹器丢弃/拾起。

## 4. 如何实现特定功能 (示例)

以下是一些使用 API 实现常见游戏功能的概念性示例。

### 示例 1: 在屏幕上显示玩家生命值

```squirrel
// Global variable to store local player's damage component
local localPlayerDamageComp = null;
local { Game } = require("HeatedMetal"); // Assuming Game is obtained this way
local Renderer; // Placeholder for how Renderer instance is obtained

// It's better to get Renderer instance if it's a class, or assume global if available
// For this example, let's assume it's available globally or obtained similarly to Game.

function UpdateHUD() {
    if (!Renderer) return; // Renderer not available

    if (localPlayerDamageComp == null) {
        local player = Game.GetLocalPlayer();
        if (player) {
            localPlayerDamageComp = player.Damage();
        }
        if (localPlayerDamageComp == null) return; // Still not found or player has no damage component
    }

    local health = localPlayerDamageComp.GetHealth();
    local maxHealth = localPlayerDamageComp.GetMaxHealth();
    local healthText = "HP: " + health + " / " + maxHealth;

    local displaySize = Renderer.GetDisplaySize();
    local textPos = Vector2(displaySize.x * 0.05, displaySize.y * 0.9); // Bottom-left corner

    Renderer.Text2D(healthText, textPos, Color(1.0, 1.0, 1.0, 1.0));
}

function OnRoundStart(worldId) {
    localPlayerDamageComp = null; // Reset on round start
    local player = Game.GetLocalPlayer();
    if (player) {
        localPlayerDamageComp = player.Damage();
    }
}

// This assumes Renderer is a globally available object or class instance.
// If Renderer needs to be instantiated or retrieved, that logic would go here.
// For example, if Renderer is part of Game API: local Renderer = Game.GetRenderer();

AddCallback_Update(UpdateHUD);
AddCallback_RoundStart(OnRoundStart);
```

### 示例 2: 创建自定义命令给予玩家武器

```squirrel
local { Game } = require("HeatedMetal");

function CmdGiveWeapon(args) {
    if (args.len() < 2) {
        print("Usage: /giveweapon <PlayerName> <WeaponObjectID>");
        return;
    }

    local targetPlayerName = args[0];
    local weaponId = args[1].tointeger();

    local targetPlayer = null;
    local playerList = Game.GetPlayerList();
    foreach(idx, player in playerList) { // Squirrel foreach provides index and value
        if (player.Name() == targetPlayerName) {
            targetPlayer = player;
            break;
        }
    }

    if (targetPlayer) {
        targetPlayer.SetItemSlot(Game.PlayerController.ItemSlot.Primary, weaponId);
        print("Gave weapon " + weaponId + " to " + targetPlayerName);
    } else {
        print("Player not found: " + targetPlayerName);
    }
}

if (Game.IsHost()) {
    RegisterCommand(CmdGiveWeapon, "giveweapon", "<PlayerName> <WeaponObjectID>", "Gives a weapon to a player.");
}
```

### 示例 3: 使实体在死亡时爆炸

```squirrel
local { Game } = require("HeatedMetal");

function OnPlayerDies(playerController) {
    if (playerController && playerController.Entity()) {
        local deadPlayerEntity = playerController.Entity();
        local explosionPos = deadPlayerEntity.GetOrigin();
        Game.CreateExplosion(explosionPos, Game.ExplosionType.NitroCell, playerController);
        print(playerController.Name() + " exploded upon death!");
    }
}

AddCallback_PlayerDeath(OnPlayerDies);
```

### 示例 4: 修改武器属性

```squirrel
local { Game } = require("HeatedMetal");

function ModifyCurrentWeaponFireRate(playerController, newRPM) {
    if (!Game.IsHost()) {
        print("Weapon modifications should ideally be done by the host.");
        return;
    }

    if (playerController) {
        local weaponComp = playerController.Weapon();
        if (weaponComp) {
            local ammoData = weaponComp.GetAmmoData();
            if (ammoData) {
                ammoData.SetFireRate(newRPM);
                print(playerController.Name() + "'s weapon fire rate set to " + newRPM);
            }
        }
    }
}
// Example:
// local player = Game.GetLocalPlayer();
// if (player) ModifyCurrentWeaponFireRate(player, 1200);
```

### 示例 5: 绘制自定义UI元素 (如准星)

```squirrel
// Assuming Renderer is globally available or obtained
// local { Game } = require("HeatedMetal");
// local Renderer = Game.GetRenderer(); // Hypothetical way to get Renderer

function DrawCustomCrosshair() {
    if (!Renderer) return;
    local displaySize = Renderer.GetDisplaySize();
    local centerX = displaySize.x / 2.0;
    local centerY = displaySize.y / 2.0;
    local crosshairSize = 10.0;
    local crosshairColor = Color(0.0, 1.0, 0.0, 0.8);

    Renderer.Line2D(Vector2(centerX - crosshairSize, centerY),
                    Vector2(centerX + crosshairSize, centerY),
                    crosshairColor, 1.5);
    Renderer.Line2D(Vector2(centerX, centerY - crosshairSize),
                    Vector2(centerX, centerY + crosshairSize),
                    crosshairColor, 1.5);
}

AddCallback_Update(DrawCustomCrosshair);
```

### 示例 6: 传送玩家

```squirrel
local { Game } = require("HeatedMetal");

function TeleportPlayer(playerController, targetPosition) {
    if (playerController) {
        playerController.SetOrigin(targetPosition);
        print(playerController.Name() + " teleported to " + targetPosition.x + "," + targetPosition.y + "," + targetPosition.z);
    }
}
// Example:
// local player = Game.GetLocalPlayer();
// if (player) TeleportPlayer(player, Vector3(100.0, 200.0, 50.0));
```

### 示例 7: 通过网络发送和接收数据

**发送端 (客户端)**:

```squirrel
local { Game } = require("HeatedMetal");

function RequestServerAction() {
    local player = Game.GetLocalPlayer();
    if (!player || !player.Entity()) return;

    local dataTable = {
        action = "spawn_item",
        itemId = 123,
        position = player.Entity().GetOrigin()
    };
    SendNetworkTable("ClientToServerAction", dataTable); // Receiver is null, sends to server
    print("Sent action request to server.");
}
```

**接收端 (服务器)**:

```squirrel
local { Game } = require("HeatedMetal");

function HandleClientToServerAction(tableName, receivedTable, senderPlayerController) {
    if (tableName == "ClientToServerAction") {
        if (!senderPlayerController) {
             print("Received ClientToServerAction but sender is null (should be client).");
             return;
        }
        print("Received action from client: " + senderPlayerController.Name());
        local action = receivedTable.rawget("action");
        local itemId = receivedTable.rawget("itemId");
        local pos = receivedTable.rawget("position"); // Assuming Vector3 can be sent

        if (action == "spawn_item" && typeof pos == "instance" && pos.instanceof(Vector3)) {
            print("Server: Spawning item " + itemId + " at " + pos.x + "," + pos.y + "," + pos.z);
            // Server logic to spawn item
            // local newItem = Game.CreateExternalEntity(itemId);
            // if (newItem) {
            //     newItem.SetOrigin(pos);
            //     newItem.AddToWorld();
            // }
            local responseTable = { status = "item_spawned", id = itemId };
            SendNetworkTable("ServerToClientNotification", responseTable, senderPlayerController);
        }
    }
}

if (Game.IsHost()) {
    AddCallback_NetworkTable(HandleClientToServerAction);
}
```

### 示例 8: 实体轮廓高亮

```squirrel
local { Game } = require("HeatedMetal");
// Assuming Renderer is available for Color
// local Renderer = Game.GetRenderer();

function HighlightAIEntities() {
    local aiList = Game.GetAIList();
    local highlightColor = Color(1.0, 0.0, 0.0, 0.7);

    foreach(idx, aiEntity in aiList) {
        if (aiEntity) {
            aiEntity.SetOutline(highlightColor);
        }
    }
}
// AddCallback_Update(HighlightAIEntities); // Call in Update for continuous highlight
```

### 示例 9: 复杂场景控制 (如电梯)

参考 `Modules/TowerElevator/main.nut` 示例，可以学习如何：

- **管理一组相关实体**: 复制现有地图部件（如电梯的平台和墙壁）并存储它们的引用及相对位置。

- **动态移动实体**: 根据计时器和预设路径（楼层高度）平滑地更新实体组的位置。

- **状态管理**: 使用变量跟踪电梯的当前楼层、移动方向和目标。

- **条件初始化**: 仅在主机上且在特定地图 (eMap.Tower) 加载时运行电梯逻辑。

- **资源清理**: 在模块关闭或回合结束时，正确移除创建的实体。

- 使用 `Game.GetEntity(ObjectID)` 获取场景中的静态部分，然后 `Duplicate()` 它们来创建动态部分。

- 通过 `AddToWorld()` 和 `RemoveFromWorld()` 控制这些复制实体的可见性和存在。

这个例子展示了如何通过组合多个 API 功能来创建复杂的、交互式的场景元素。

## 5. 重要注意事项与最佳实践

- **Pointer 类**: 再次强调，直接使用 Pointer 类进行内存操作非常危险。除非您确切知道自己在做什么，否则应避免使用它，因为它很容易导致游戏崩溃或不可预测的行为。

- **性能**:
  - 在 `AddCallback_Update` 中执行的代码会每帧运行，请确保其高效。避免复杂或耗时的计算。
  - 对于长时间运行的循环，使用 `Yield()` 来防止游戏冻结。

- **错误处理**: Squirrel 支持 `try...catch` 块。在可能失败的操作或访问可能为 null 的对象属性之前，进行检查（例如 `if (myEntity != null)`）或使用错误处理。

- **对象生命周期**: 注意游戏对象的生命周期。在访问实体或组件之前，检查它们是否仍然有效（不为 null）。例如，玩家可能已断开连接，其实体可能已被移除。

- **客户端 vs. 服务器**: 明确哪些逻辑应该在客户端运行，哪些应该在服务器（主机）运行。影响游戏状态的更改（如玩家生命值、物品栏、分数）通常应由服务器权威处理，以防止作弊并确保所有玩家的一致性。客户端可以预测结果以获得更流畅的体验，但最终状态应由服务器决定。

- **模块化**: 将您的代码组织成函数和类，以提高可读性和可维护性。

- **版本兼容性**: API 可能会随着游戏更新而改变。留意 `HMVersion()`，并准备好在必要时更新您的脚本。

### 脚本结构

一个良好的脚本模块通常具有以下结构：

```squirrel
// 1. 导入所需模块
local { Game } = require("HeatedMetal");
local math = require("math"); // Example other module

// 2. 定义模块级变量和常量
local MY_CONSTANT = 100;
local moduleState = {};

// 3. 定义辅助函数
function HelperFunction1() {
    // ...
}

// 4. 定义回调函数
function OnUpdate_Callback() {
    // Logic for each frame
}

function OnRoundStart_Callback(worldId) {
    // Logic for round start
    if (Game.IsHost() && worldId == eMap.MyCustomMap) {
        // Initialize map specific things
    }
}

function OnShutdown_Callback() {
    // Cleanup logic when module is shutting down
}

// 5. 主逻辑/初始化函数
function Main() {
    print("MyModule Loaded.");
    // Register callbacks
    AddCallback_Update(OnUpdate_Callback);
    AddCallback_RoundStart(OnRoundStart_Callback);
    AddCallback_Shutdown(OnShutdown_Callback);

    // Other initialization
}

// 6. 调用主函数 (模块入口点)
Main();
```

本文档提供了 HeatedMetal API 的概览和一些基本用法。深入研究头文件中的注释，并进行实验，是掌握此 API 的最佳方式。祝您脚本编写愉快！