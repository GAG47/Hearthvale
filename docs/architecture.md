# Hearthvale 软件架构

## 文档目的

本文以概念级职责领域描述 Hearthvale 软件架构，明确不同职责之间的边界以及世界事实如何产生和改变。

这里的职责领域不是代码模块设计，不对应固定的 Manager、目录、基类、接口或数据格式。实际代码结构只在具体需求出现后决定。

## 职责领域

| 职责领域 | 负责 | 不负责 |
| --- | --- | --- |
| World State | 记录世界中已经成立的事实和当前状态 | 判断行为是否合法、决定角色意图、生成表现内容 |
| World Rules | 判断行为是否合法，并确定行为产生的游戏规则结果 | 采集输入、呈现画面、用开放性内容替代确定性规则 |
| Actions / Interactions | 表达角色对世界采取的行动与交互意图 | 自行判定是否合法、绕过规则直接改变世界事实 |
| Actors | 表达世界中的行动主体，包括玩家和 NPC | 因主体身份不同而擅自改写世界规则、直接宣布行动结果成立 |
| World Simulation | 推进时间，驱动并组织非玩家直接触发的世界变化 | 代替所有游戏规则、任意写入未经验证的世界结果、承担画面表现 |
| Content / AI | 提供开放性、语义性、创造性内容与决策建议 | 拥有规则权威、直接确定或修改世界事实 |
| UI / 表现层 | 承担 Godot 中玩家实际看到和操作的场景、画面、UI、输入及其他表现 | 成为世界事实的唯一来源、在表现层自行决定游戏规则结果 |

## 领域之间的基本关系

玩家、NPC 和世界模拟都可能成为世界变化的来源，但它们提出的意图或变化必须经过游戏规则处理，才能成为世界事实。

典型的概念关系是：

```text
变化来源
  ├─ 玩家通过 UI / 输入层表达操作意图
  ├─ NPC 作为 Actor 作出行动决定
  ├─ World Simulation 推动时间与世界变化
  └─ Content / AI 提供内容或决策建议
          ↓
Actions / Interactions 表达将要发生的行为
          ↓
World Rules 验证并确定规则结果
          ↓
游戏系统执行已确认的结果
          ↓
World State 记录新的世界事实
          ↓
UI / 表现层呈现世界状态与结果
```

这是一条职责关系，不是对调用顺序、代码依赖或 API 形式的预先规定。

## 空间关系

当前空间采用世界层与场景层两级关系。

世界层由世界节点（Location）及节点间的直接连接组成。一个节点表示一个可以进入、活动和离开的地点；室内与室外节点遵循同一种空间关系，不建立两套地点体系。当前不增加 Region、国家或大陆等上层结构。

场景层把一个世界节点表现为 2D 格子场景。格子是场景结构的最小单位，用于组织地面、建筑、障碍和出口，但不是角色移动的离散步长。角色在格子构成的空间中连续移动，并由碰撞限制可通行范围。

一个节点连接在概念上包含两个必要信息：目标节点，以及进入目标节点时对应的位置。连接是有向的；两个地点之间的双向通行由两条边分别表达，不从其中一条自动推断另一条。连接本身不负责旅行时间、路径搜索或更大范围的地图模拟。

## World Definition 与 Location Graph

WorldDefinition 是当前静态世界结构的统一来源，与保存运行时变化事实的 WorldState 分离。它持有全世界的 LocationDefinition 目录，因此即使对应 Location Scene 没有实例化，系统仍可以查询该地点及其直接连接。

每个 LocationDefinition 当前只包含已经有消费者的信息：

- 稳定 `location_id`；
- 正常可读的 `display_name`；
- 承载该地点的 `scene_path`；
- 从该地点出发的 `outgoing_edges`。

Location 是有向图节点，每个 LocationDefinition 管理自己的出边。每条边以仅在所属 Location 内唯一的 `edge_key` 识别，并只保存 `to_location` 与 `to_entry`。边不重复保存 `from_location`，也不预先包含旅行分钟、距离、成本或动态道路状态。

当前三个节点与四条有向边是：

```text
town_street --tavern_door--> tavern --back_door--> tavern_yard
town_street <--front_door--- tavern <--tavern_door-- tavern_yard
```

GridScene 继续声明自己的 `location_id` 并负责具体格子空间、入口坐标和出口触发位置。LocationEntry 以稳定 `entry_id` 标识场景内落点；LocationExit 只保存 `edge_key`，不保存目标 Scene 路径或目标 Entry。地点显示名与 Scene 映射来自 LocationDefinition，不在每个出口中重复。

玩家触发出口后的基础流程是：

```text
当前 GridScene.location_id + LocationExit.edge_key
  ↓
WorldDefinition 查询有向边
  ↓
Prepare
  ├─ 查询目标 LocationDefinition，加载并实例化目标 Scene
  ├─ 验证 GridScene 身份、来源、出口和目标 LocationEntry
  ├─ 计算迁移 Actor 的目标落点
  ├─ 确认目标 Location 中需要表现的 Entity
	└─ 对每个 Entity 请求 EntityRepresentationRegistry
	      ├─ 找到唯一支持该 Entity 的 EntityRepresentationFactory
	      └─ Factory 创建并 Prepare 对应 Representation
          ↓ 全部成功
Commit
  ├─ 同步旧 ActorRepresentation 的最后位置
  ├─ 修改迁移 ActorState 的 Location 与位置
  ├─ 激活已经准备好的目标 Location 与 Representation
  ├─ PlayerController 换绑新的 ActorRepresentation
  ├─ 更新 current_location
  └─ 释放旧 Location
```

Location 切换采用 Prepare → Commit。Prepare 允许创建临时目标 Location 与 Representation，但不修改正式 WorldState 或 EntityState，不释放当前 Player Representation，不改变 PlayerController 控制对象、`current_location` 或旧 Location。Actor 四向视觉、家具视觉与碰撞结构、目标玩家表现等所有正常可能失败的准备检查也在这一阶段完成。目标 Location 中每个应被表现的 Entity 都必须恰好匹配一个 Factory；零匹配或多匹配都会使整个 Prepare 失败，不能静默跳过 Entity。任何 Prepare 失败只释放本次临时内容，旧 Location、WorldState 与控制关系从未被修改，因此不需要 rollback。

只有 Prepare 全部成功才进入 Commit。Commit 使用已经验证和加载的内容完成正式 State 迁移与表现换绑，不再加载 Scene 或视觉资源，也不再查找 Entry 或执行 Representation 结构验证。Location 切换只重建 Representation，不重新创建 Entity、EntityState 或 BehaviorState。

WorldDefinition 初始化继续校验 Location ID、Scene 资源、局部 edge key、目标 Location 和非空 Entry 标识，并加载全部 Location Scene 做静态图与实际场景的一致性验证。Scene 实例化后双向检查 LocationExit 与 outgoing edge：Scene 中每个 Exit 必须引用已定义边，Definition 中每条边也必须有实际 Exit；同时检查 Scene 身份、Scene 来源、Entry 唯一性，以及每条边的 `to_entry` 在目标 Location Scene 中真实存在。错误信息携带相应的 Location、edge、目标 Location 和 Entry，便于定位静态世界定义。

Location Graph 当前只表达静态空间拓扑。NPC 路线、日程、离屏模拟、旅行时间、距离、道路封锁、天气影响、事件改路和世界地图 UI 尚未实现；未来系统可以查询该图，但不应把这些未确定职责提前塞入边定义。

## 地图结构与 Entity

Location 内的地图结构与逻辑实体表达不同的事实。TileMapLayer / TileSet 描述地面、墙体、道路和建筑边界；世界规则需要赋予独立身份、持续动态状态并单独引用的对象进入 Entity 体系，不把状态塞进瓦片或临时 Scene Node。当前已经实现的 Entity 大类是 Actor 与 Furniture，但这不是封闭列表。

Entity 是拥有独立身份、独立动态状态，并需要被世界规则单独引用的逻辑对象。判断一个内容是否需要成为 Entity，不看它是否出现在 Scene 中、拥有 Sprite 或碰撞、能够交互，而看世界规则是否需要独立识别、持续追踪并引用它。地板、墙面装饰、草、阴影、粒子和其他纯视觉装饰不会仅因出现在 Scene 中就成为 Entity。

所有 Entity 遵循相同的基础规则：

- 使用全世界唯一、创建后不变的 UUID v4 `entity_id`；
- 持有独立 EntityState，记录该实例已经成立的动态世界事实；
- 可以在没有 Representation 的情况下继续存在；
- Location Scene 卸载不能删除对应的逻辑 Entity 或 State；
- 需要显示时，创建适合该类 Entity 的 Representation，并绑定原有 Entity 与 State。

Entity 是很薄的 RefCounted 逻辑基类，只持有 EntityState，提供身份、当前位置与 Location 访问，以及默认“不支持”的 Action 目标协议。Actor 表达行动主体，Furniture 表达当前家具和环境实体；只有真实需求证明另一类实体具有根本性的基础结构、生命周期或基础规则差异时，才建立新的 Entity 大类。本文不提前规定未来一定存在的具体 Entity 类型或对应代码结构。

### Entity 的继承、组合与数据边界

Entity 体系中的结构按以下含义区分：

- Entity 大类表达根本结构、生命周期或基础规则差异；
- Definition 描述具体内容“是什么”；
- Behavior / Component 描述“能做什么”以及能力如何运行；
- BehaviorState / ComponentState 保存某项可组合能力在具体实例上的动态状态；
- EntityState 保存该 Entity 本身共有的动态世界事实；
- Representation 只是 Entity 在当前加载 Scene 中的表现。

同一个 Entity 大类内部，不应通过不断增加具体内容子类表达能力差异。Furniture 不因为出现 Bed、Chest 或 Table 就分别建立大量逻辑类型类；这类差异优先由 Definition 与真实存在的 Behavior 组合表达。

如果一项可组合能力拥有独立动态状态，其 State 也应随能力组合，不应把 `is_open`、`occupied_actor`、`inventory`、`crafting_progress` 等专属字段不断加入公共父级 State。没有独立动态状态的 Behavior / Component，不需要为了形式完整而建立空 State。当前 FurnitureState 通过 `behavior_states` 组合能力状态；只有 OpenableState 保存 `is_open`，Sleepable 与 Inspectable 没有动态事实，因此没有对应空 State。

Entity 统一规范不意味着所有 Entity 必须拥有同一种 Definition、完全相同的 Behavior 或同一种 Representation，也不要求建立万能 EntityDefinition、万能 EntityRepresentation 或完整 ECS。具体结构仍由真实需求、真实消费者和真实状态决定，不为形式对称增加抽象。

WorldState 与 Runtime Entity 持有同一个 EntityState 对象，不复制两份事实。Representation 永远只是 Entity 在当前 Scene 中的表现，不能反过来成为逻辑身份、权威状态或规则结果的唯一来源。

EntityRegistry 以 UUID v4 `entity_id` 统一管理当前 Runtime Entity，提供注册、按 ID 查询、稳定遍历与按 Location 查询。登记只检查 Entity 的共同条件：Entity 与 EntityState 存在、UUID 合法且双方 ID 一致；Registry 不认识 Actor、Furniture 或其他具体子类。它不加载 Definition，不创建 Entity、State 或 Representation，也不执行 Action。Location 加载及临时世界内容初始化仍由当前 Game 流程完成。

### Entity Lifecycle / Baking

人工固定世界内容遵循完整生命周期：

```text
Location Scene
  ↓
ActorPlacement / FurniturePlacement
  └─ 直接引用 → ActorDefinition / FurnitureDefinition Resource（ResourceUID）
  ↓ 开发阶段 Baking
EntityBakerRegistry → 唯一 EntityBaker
  ↓
Initial Entity Data
  ↓ New World 当前启动流程
EntityFactoryRegistry → 唯一 EntityFactory
  ↓ Prepare：创建并验证全部 Entity + EntityState
Entity + EntityState
  ↓ Commit：统一注册
EntityRegistry + WorldState
  ↓ Location 加载
Entity Representation System
  ↓
Representation
```

EntityPlacement 是只供制作阶段使用的 Authoring Data，不是 Entity、EntityState 或 Representation。ActorPlacement 与 FurniturePlacement 直接保存强类型 ActorDefinition / FurnitureDefinition Resource 引用及初始摆放数据，不保存 Definition 路径字符串；位置直接来自 Node2D.position，Location ID 在 Baking 时由所属 LocationDefinition / GridScene 确定。Placement 不保存 UUID、BehaviorState 或运行时 Entity 引用；正常 Location 激活前会从场景树移除，不能参与 Action、Interaction、Collision、EntityRegistry、WorldState 或 Representation 创建。

Placement 是 `@tool` Authoring Node。ActorPlacement 在 2D Editor 中按 `initial_facing` 从同一 ActorDefinition 取得方向 Texture2D；FurniturePlacement 绘制同一 FurnitureDefinition 的视觉及按运行时格子规则计算的 `occupied_cells`。Definition 中会影响 Preview、校验或运行配置的导出属性在修改时发出 `changed`；Placement 监听该信号，与 facing 或绑定变化一样立即重绘并更新 Godot Configuration Warning。Placement 的 Warning 包含 Definition 的完整 `get_validation_warnings()` 结果，Baker 复用同一套 Definition 规则，避免 Editor 预检与 Baking 结果分歧。Preview 不创建 Entity、State、碰撞或 Representation，运行时激活仍会移除 Placement。

Baking 是明确执行的开发阶段转换，不发生在 New World 或 Location 加载期间。Bake Initial World 从 WorldDefinition 的正式 LocationDefinition 目录枚举 Scene，按 Location ID 和 Scene 中稳定顺序收集 Placement，经 EntityBakerRegistry 找到唯一 Baker，再输出 `data/world/initial_entities.json`。EntityBaker 是 RefCounted，只把 Placement 转换成可序列化 Initial Entity Data，不生成 UUID，也不创建 Entity、EntityState 或 Representation。零匹配和多匹配都会使整体 Baking 失败；所有数据验证成功后才替换输出文件。

Initial Entity Data 当前以 `schema_version` 和 `entities` 记录新世界所需的创建数据。V9.2 引入 `definition_uid` 后的当前 Schema Version 是 2，由 `InitialEntityDataSchema.VERSION` 唯一定义，Baking Writer 与 Loader 共用，Loader 明确拒绝其他版本。每条数据明确保存 `entity_type`、`definition_uid`、`location_id`、`local_position`，Actor 另存 `initial_facing`；它不保存 Definition 文件路径或运行时 UUID，也不根据 Node、Scene 或 Definition 文件名猜类型。`definition_uid` 是 `uid://...` 格式的 Godot ResourceUID，因此 Definition 资产在编辑器中移动或重命名后仍可由稳定身份解析。

EntityFactory 是运行时统一创建入口，负责把 Initial Entity Data 或未来程序生成的同格式创建数据转换为 Entity + EntityState。ActorEntityFactory 与 FurnitureEntityFactory 通过 `definition_uid` 加载并验证正确类型的 Godot Resource，为世界实例生成永久 `entity_id`，再创建对应 State 和 Entity；Furniture 继续通过现有 Furniture 构造逻辑初始化 Behavior / BehaviorState。EntityFactory 不依赖 Definition 当前路径，也不创建或持有 Representation。

固定 Entity 初始化采用 Prepare → Commit。Prepare 读取全部 Initial Entity Data，为每条数据取得唯一 Factory，创建并验证全部临时 Entity + EntityState，同时检查 Location、UUID、Entity / State 对应关系以及待注册批次内和正式 Registry 中的 ID 冲突；这一阶段不修改 WorldState 或 EntityRegistry。只有整个批次成功才进入 Commit，通过两个 Registry 的批量注册接口统一登记所有 State 与 Entity。中间任何一条创建或验证失败都不会产生部分 Entity、孤立 State 或其他半初始化结果。Game 的注册逻辑始终面向通用 Entity，不按 Actor / Furniture 类型分支。

人工固定内容经过 Placement → Baking → Initial Entity Data；未来程序或 AI 生成内容可以直接产生 Entity 创建数据。两种来源统一进入 EntityFactory，之后使用相同的 EntityState、注册和 Representation 流程。Placement 只影响新世界初始数据；一旦 EntityState 已建立，Location 重载必须从 State 恢复位置和行为状态，不能重新读取 Placement。当前 Player 初始化仍属于独立的 Session 启动职责，没有迁入 Placement Baking。

### Entity Representation System

Representation 是 Entity 在当前加载 Scene 中的临时空间表现。Entity 的逻辑存在不依赖 Representation；Location 加载或卸载可以创建、销毁和重建 Representation，而不删除或替换 Entity、EntityState 与 WorldState 中的权威事实。依赖方向只能从 Representation 层指向 Entity：Entity 不创建、持有或指定自己的 Representation，也不知道 PackedScene、Sprite、Collision 或 Scene Node 的创建方式。

Entity 类型与 Representation 类型之间的对应关系属于 Representation 层。`EntityRepresentationFactory` 是不进入 SceneTree 的 RefCounted 抽象，提供 `supports(entity)` 和 `prepare(entity, target_location, target_local_position)`；具体 Factory 持有对应 Scene 与准备知识，成功返回已经完整准备的 Node，失败返回 `null`。当前 `ActorRepresentationFactory` 负责 Actor 的 Scene、四向视觉、碰撞与目标位置，`FurnitureRepresentationFactory` 负责 Furniture 的 Scene、状态视觉、占位阻挡与目标位置。

`EntityRepresentationRegistry` 与保存 Entity 实例的 EntityRegistry 完全分离。它只注册 Factory，并扫描全部 Factory 为 Entity 找到唯一匹配：零个或多个匹配都是配置错误，只有恰好一个匹配才返回。`create_default()` 在 Representation 子系统内部固定注册当前 Actor 与 Furniture Factory；Game 只取得已组装的 Registry，不知道具体 Factory、Representation Scene 或视觉和碰撞准备方式。以后增加需要空间表现的 Entity 大类时，应新增对应 Representation 与 Factory，并只扩展默认 Registry 组装，不在 Game 增加 Entity 类型分支。

Representation 的统一是职责和创建流程统一，不是 Godot Node 继承结构统一。系统不建立公共 `EntityRepresentation extends Node` 基类；ActorRepresentation 继续使用 CharacterBody2D，FurnitureRepresentation 继续使用 Node2D，未来类型可以选择符合自身空间职责的 Node。当前 Representation 通过共同约定提供绑定的 Entity，Scene 空间选择完成后必须取得逻辑 Entity 再交给 Action，WorldAction 不操作 Representation。

每个 GridScene 只维护当前已加载 FurnitureRepresentation 的格子索引。FurnitureRepresentation 根据绑定 Furniture 的占用范围登记到每个格子，离开场景时注销。这个索引用于 Scene 空间命中，不是 EntityRegistry 或 WorldState；Selector 命中 Representation 后必须返回其逻辑 Furniture。

## Location、Scene 与运行时 World State

Scene、Location 与 World State 表达不同职责：

- Location 是世界中的逻辑地点，以稳定 `location_id` 识别，并作为空间归属、格子索引和局部查询边界；
- Godot Scene 是该 Location 当前被加载后承担显示、碰撞、交互和场景行为的运行时表现；
- World State 是独立于 Location Scene 生命周期持续存在的动态世界事实。

世界身份使用稳定逻辑 ID。Location 继续使用 `location_id`；ActorDefinition 与 FurnitureDefinition 是 Godot Custom Resource，其静态资产身份由 Godot ResourceUID 管理，不再维护自定义 `definition_id`。每个世界中的具体 Entity 实例使用独立 UUID v4 `entity_id`。ResourceUID 回答“哪一份静态 Definition 资产”，`entity_id` 回答“当前存档世界中的哪一个实例”，两者不能互相代用。Entity UUID 不编码名称、类型、Location、职业、用途、生成顺序或状态，创建后不变；UUID Generator 只生成 Entity UUID，格式验证是独立职责。

Definition 与 State 保持分离。Initial Entity Data 通过 `definition_uid` 找到 Custom Resource；EntityFactory 另行生成 `entity_id` 并写入 EntityState 与 Entity。ActorDefinition 以强类型 String 与四张 Texture2D 描述角色名称和方向视觉；FurnitureDefinition 以 String、Texture2D、Vector2i、bool 和 Behavior 配置描述家具静态内容。具体实例的 Location、位置、朝向或开启状态只进入相应 EntityState。TileMap、CollisionShape、Sprite 和 SceneTree 都不复制到 WorldState。

WorldState 是随当前游戏运行持续存在的 Autoload，以 `entity_id → EntityState` 统一保存 Entity 的动态状态，当前实际类型包括 ActorState 与 FurnitureState，并继续独立保存 WorldTimeState。它不加载 Definition、不创建 Entity，也不解释家具行为。Scene Node 被释放不代表逻辑实体或世界事实删除：Location 重载会创建新的 Representation，绑定 EntityRegistry 中同一 Entity 及 WorldState 中同一 State。

Location 的格子索引仍是当前已加载 Scene 的局部查询结构，不是 World State。当前运行时 WorldState 也不是磁盘存档；未来 Save / Load 应序列化这份世界事实结构，而不是建立另一套权威。当前不实现文件格式、版本迁移或存档槽。

## 统一世界时间

世界时间是世界级事实，不属于某个 Entity，也不依附当前加载的 Location Scene。WorldTimeState 与 EntityState 集合分离，当前只保存一个权威基础量 `total_minutes`。年、月、日、时、分、星期和季节全部由该值及统一日历规则推导，不作为平行字段重复保存，因而不存在多个日期字段相互失配的问题。

WorldState 持有 WorldTimeState，使它与其他运行时世界事实一样跨 Location Scene 生命周期持续存在。独立的 WorldTime 运行时服务负责解释并改变这份事实，包括帧率无关的自然流逝、按分钟推进、推进到指定未来时刻、日历换算以及变化通知。Location、HUD 和具体 Furniture 不各自维护当前时间，也不直接操作 `total_minutes`。

当前日历常量集中在同一处：一年 12 个月、每月 30 天、一周 7 天、一天 24 小时、每小时 60 分钟；第一年一月一日是 Monday，四季各覆盖连续三个月。运行时初始事实是第一年一月一日 08:00。自然时间使用小数秒累积，当前统一速率是 1 个真实秒对应 1 个游戏分钟；时间节点遵循 SceneTree 暂停，不在暂停期间自然推进。

时间服务在推进后通知总分钟变化，并分别报告跨过的分钟、绝对小时边界和绝对天边界。一次大跨度推进只需一次通知即可携带变化前后范围与跨越数量，未来消费者能够据此处理所有跨界，不必假定每次只增加一分钟。当前不在时间系统中预建事件调度器或 NPC 日程系统。

睡眠仍沿用正式 Action 链：公共空间规则和 SleepableBehavior 通过后，请求 WorldTime 推进到下一天 08:00；日期进位与跨月、跨年计算由时间服务负责。Furniture 不保存另一份日期，也不直接写 WorldTimeState。HUD 属于 UI / 表现层，只订阅时间变化并读取派生值进行显示，不拥有或修改世界时间。

## Actor、Furniture、Behavior 与表现

Actor extends Entity，并关联 ActorDefinition Resource 与 ActorState。ActorDefinition 当前保存 `display_name` 和 `visual_up/down/left/right` 四个 Texture2D 引用，资产身份由 ResourceUID 提供；ActorState 在公共 EntityState 上增加四方向 `facing`。ActorEntityFactory 直接使用按 UID 加载的 ActorDefinition，并为 Actor / ActorState 生成独立 `entity_id`。ActorPlacement Preview 与 ActorRepresentation 都从同一 Resource 读取对应 facing 视觉；卸载前 Representation 把 Scene 中的连续位置同步回同一个 State。

Furniture extends Entity，并关联可共享的 FurnitureDefinition Resource、实例独享的 FurnitureState 和一组轻量 Behavior。FurnitureDefinition 的 ResourceUID 标识静态资产，Furniture / FurnitureState 的 `entity_id` 标识世界实例。床、储物箱、告示牌都是 `.tres` Custom Resource，不存在 Bed、Chest、Sign 逻辑子类。SleepableBehavior、OpenableBehavior、InspectableBehavior 分别封装当前睡眠、开关与查看规则；`is_open` 属于 `FurnitureState.behavior_states.openable` 中的 OpenableState，关闭与开启视觉是 Definition 中的 Texture2D 引用，Behavior 对象不保存具体家具实例状态。FurniturePlacement Preview 与 FurnitureRepresentation 读取同一 Definition visual，Behavior 的通用反馈从 FurnitureDefinition.display_name 取得名称。

所有家具共用 FurnitureRepresentation Scene。它只绑定已有 Furniture，按 Definition / State 设置视觉、位置、占位碰撞，并把自身登记到当前 GridScene 的空间索引；它不生成 UUID，不创建或注册 Entity / State，也不判断 Action。OpenableState 变化后 Representation 只负责刷新视觉。离开酒馆会释放这些 Node，重新进入时创建的新 Representation 会绑定原 Furniture、原 FurnitureState 与其中同一个 OpenableState，因此直接恢复开启状态。

PlayerController 独立持有当前受控 Actor 和它在已加载 Location 中的 ActorRepresentation，继续负责输入、连续移动、交互意图、结果信号和 Camera。当前 Player Definition 是具有 ResourceUID 的 ActorDefinition `.tres`，Session 启动流程另行生成 Player Actor / ActorState 的 `entity_id`。角色与 Camera 跟随在物理帧更新，并使用 2D 物理插值平滑渲染；Location 切换后 Controller 绑定同一 Actor 的新 Representation。Actor 与 ActorRepresentation 不保存 Player 类型标记，Player 只表示当前控制权。Martha ActorDefinition Resource 仍可加载，但在通用 NPC 初始化出现前不创建 Runtime Entity、State 或 Representation。

## 当前交互与行为关系

玩家按下统一交互输入时，PlayerController 请求 InteractionTargetSelector 先查询当前受控 ActorRepresentation facing 方向的相邻格，再查询其当前格。查询使用当前 Location 的 FurnitureRepresentation 格子索引，不遍历 SceneTree；命中 Representation 后取出逻辑 Furniture，并按稳定 `entity_id` 选择一个支持行为的 Entity 返回。这一过程只负责确定意图目标，不让家具分别监听输入，也不是 Action 合法性的唯一防线。

选中目标后的当前基础关系是：

```text
PlayerController 把玩家输入转化为移动或交互意图
  ↓
ActorRepresentation 绑定 Actor、执行当前 Scene 中的空间移动并同步状态
  ↓
Location / GridScene 维护自身格子中的 FurnitureRepresentation
  ↓
InteractionTargetSelector 从 Representation 命中取得逻辑 Entity
  ↓
WorldAction 表达逻辑 Actor、行为身份和 Entity 目标
  ↓
公共空间规则验证同一 Location 与当前格 / facing 相邻格
  ↓
Entity 的 Action 目标协议进行检查与执行
  ↓
Furniture override 协议并把具体规则委派给对应 Behavior
  ↓
执行并修改 EntityState / WorldTimeState
  ↓
Representation 根据逻辑状态更新当前表现
  ↓
ActionResult（success / failure、消息与失败代码）
  ↓
HUD / UI 显示 ActionResult
```

公共空间规则属于 WorldAction 执行链，依赖逻辑 EntityState 验证 Actor 与 Entity 目标有效、属于同一个 Location，并且目标占据 Actor 当前格或 facing 相邻格；通过后，WorldAction 只调用 Entity 的 `check_action()` 与 `apply_action()`。Entity 默认拒绝，Furniture override 后委派 Behavior；WorldAction 不认识 Furniture 或任何其他目标子类。Scene / Physics 只参与目标命中，Action 不操作 FurnitureRepresentation。即使未来 NPC、AI 或其他系统绕过玩家 Selector 直接创建 WorldAction，非法空间行为也不能修改目标状态。

行为合法性判断与执行保持分离。PlayerController 只从目标 Entity 请求 primary action、产生玩家意图并发出结果，不强转具体目标，也不直接修改家具状态或更新交互结果 UI。空间拒绝同样返回正式 ActionResult 和明确失败代码。合法 open / close 修改权威 OpenableState，Representation 只根据同一状态更新视觉。正式结果不只服务玩家画面；未来 NPC 或 AI 发起行为时，也应能得到相同的成功、失败和原因信息。

## 世界事实的权威边界

World State 记录已经成立的世界事实，但事实不能仅凭输入、角色意图、模拟建议、表现效果或生成内容而成立。确定性的世界状态变化必须来自经过 World Rules 验证、并由游戏系统执行的结果。

玩家和 NPC 都是世界中的 Actors。当两者采取本质相同的行为时，应由同一个世界中的游戏规则判断，而不是因为控制来源不同就天然获得不同的规则权威。

World Simulation 可以推动时间并发起非玩家直接驱动的变化，但这些变化仍需遵守世界规则。它负责让世界运转，不因此获得绕过规则修改事实的权力。

## 静态 Resource、存档数据与 AI JSON

Hearthvale 的三类数据具有不同职责。项目随版本发布的静态内容使用 Godot Resource，例如 ActorDefinition、FurnitureDefinition 及未来其他固定 Definition；这些资产使用 ResourceUID 稳定引用，适合 Inspector、类型检查、资源依赖与编辑器预览。

具体世界已经发生的动态事实属于存档数据，例如 EntityState、BehaviorState、Memory、Relationship、World Event 与未来 AI Generated World Data。它们必须按世界实例保存和恢复，不能写回静态 Definition，也不能在 Load Game 时重新从 Placement 或 Baking 覆盖。

JSON 保留为未来 AI 系统的输入输出边界，不作为当前内部静态 Definition 格式。未来流程应是 Hearthvale 内部模型选择必要信息 → AI Context JSON → LLM → Structured JSON → 验证 → 转换回 Hearthvale 内部模型。V9.2 只确定这条数据边界，不实现 AI 调用、Memory、Relationship 或生成世界系统。

## AI 的权威边界

AI 是内容与决策建议来源，不是世界权威。它可以提出角色可能采取的行动、生成开放性内容或为系统提供建议，但不能直接宣布行动成功、物品出现、角色状态改变或其他世界事实已经发生。

AI 参与世界变化时必须遵循：

```text
AI 提议 → 游戏规则验证 → 游戏系统执行 → World State 改变
```

AI 的输出即使被接受，也必须通过与该行为相适应的规则和执行过程。

## Representation 与逻辑世界

PlayerController 负责把玩家输入转化为可供游戏处理的意图；Representation 负责把 Entity 及其状态映射为当前加载 Scene 中的临时空间 Node，包括对应的视觉、碰撞和空间关系。UI、HUD、声音及其他反馈属于更广义的 UI / 表现层，不等同于 Representation。当前已经实现 ActorRepresentation 与 FurnitureRepresentation，它们不共享公共 Node 基类，各自保留适合自身空间职责的 Godot Node 类型。

Representation 可以维护表现所需的临时状态，但永远只是 Entity 在当前加载 Scene 中的表现，不能把画面上看似发生的事情直接当作已经成立的世界事实。逻辑世界也不应依赖某个特定界面或验证场景才能成立。

ActorRepresentation 与 FurnitureRepresentation 都按稳定 `entity_id` 绑定 EntityRegistry 中的逻辑 Entity，能够返回该 Entity，并从 WorldState 持有的同一 EntityState 恢复表现。两者都允许 Scene Node 随 Location 加载和卸载，而权威动态状态继续存在。其他 Scene 与逻辑世界的绑定只在出现真实需求时决定。

## 暂不规定的实现事项

除已由实际功能建立的当前边界外，本文不提前规定未来的类、文件、JSON Schema、Godot Node 或 Resource 选择、signal、Manager、API、存档格式和具体算法。它们应在对应需求清楚后单独设计。
