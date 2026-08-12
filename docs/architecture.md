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
| Presentation | 承担 Godot 中玩家实际看到和操作的场景、画面、UI、输入及其他表现 | 成为世界事实的唯一来源、在表现层自行决定游戏规则结果 |

## 领域之间的基本关系

玩家、NPC 和世界模拟都可能成为世界变化的来源，但它们提出的意图或变化必须经过游戏规则处理，才能成为世界事实。

典型的概念关系是：

```text
变化来源
  ├─ 玩家通过 Presentation 表达操作意图
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
Presentation 呈现世界状态与结果
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
取得 to_location + to_entry
  ↓
WorldDefinition 查询目标 scene_path
  ↓
实例化并验证目标 GridScene.location_id
  ↓
按 entry_id 定位目标 LocationEntry
  ↓
卸载当前 Location，进入目标 Location 的实际落点
```

目标 Scene 会在当前 Location 卸载前完成身份、出口和目标 Entry 验证，错误定义不会用半完成的切换替换当前场景。WorldDefinition 初始化校验 Location ID、Scene 资源、局部 edge key、目标 Location 和非空 Entry 标识，并加载全部 Location Scene 做静态图与实际场景的一致性验证。Scene 实例化后双向检查 LocationExit 与 outgoing edge：Scene 中每个 Exit 必须引用已定义边，Definition 中每条边也必须有实际 Exit；同时检查 Scene 身份、Scene 来源、Entry 唯一性，以及每条边的 `to_entry` 在目标 Location Scene 中真实存在。错误信息携带相应的 Location、edge、目标 Location 和 Entry，便于定位静态世界定义。

Location Graph 当前只表达静态空间拓扑。NPC 路线、日程、离屏模拟、旅行时间、距离、道路封锁、天气影响、事件改路和世界地图 UI 尚未实现；未来系统可以查询该图，但不应把这些未确定职责提前塞入边定义。

## 地图结构与 Entity

Location 内的地图结构与逻辑实体表达不同的事实。TileMapLayer / TileSet 描述地面、墙体、道路和建筑边界；需要稳定身份、动态状态或独立行为的角色与家具则进入 Entity 体系，不把状态塞进瓦片或临时 Scene Node。

Entity 是很薄的 RefCounted 逻辑基类，只持有 EntityState，并提供 `entity_id`、当前位置与 Location 访问。当前两个具体分支是 Actor 与 Furniture：Actor 表达行动主体，Furniture 表达床、储物箱和告示牌等环境实体。Entity 不负责 Sprite、碰撞、输入、AI 或具体 Action 规则。

EntityState 统一保存所有实体共同的 `entity_id`、`current_location_id` 与 `local_position`。ActorState 增加 `facing`；FurnitureState 当前增加储物箱需要的 `is_open`。WorldState 与 Runtime Entity 持有同一个 State 对象，不复制两份事实。

EntityRegistry 以 UUID v4 `entity_id` 统一管理当前 Runtime Entity，提供注册、按 ID 查询、稳定遍历与按 Location 查询。它不加载 Definition，不创建 Entity、State 或 Presentation，也不执行 Action。Location 加载及临时世界内容初始化仍由当前 Game 流程完成。

每个 GridScene 只维护当前已加载 FurniturePresentation 的格子索引。FurniturePresentation 根据绑定 Furniture 的占用范围登记到每个格子，离开场景时注销。这个索引用于 Scene 空间命中，不是 EntityRegistry 或 WorldState；Selector 命中 Presentation 后必须返回其逻辑 Furniture。

## Location、Scene 与运行时 World State

Scene、Location 与 World State 表达不同职责：

- Location 是世界中的逻辑地点，以稳定 `location_id` 识别，并作为空间归属、格子索引和局部查询边界；
- Godot Scene 是该 Location 当前被加载后承担显示、碰撞、交互和场景行为的运行时表现；
- World State 是独立于 Location Scene 生命周期持续存在的动态世界事实。

世界身份使用稳定逻辑 ID。Location 继续使用 `location_id`；Actor 与 Furniture 统一使用全世界唯一的 UUID v4 `entity_id`。UUID 不编码名称、类型、Location、职业、用途、生成顺序或状态，创建后不变；UUID Generator 只生成 UUID，格式验证是独立职责。

Definition 与 State 保持分离。ActorDefinition 描述角色名称和四向视觉；FurnitureDefinition 描述家具种类、静态视觉、占位、阻挡与 Behavior 配置。具体实例的 Location、位置、朝向或开启状态只进入相应 EntityState。TileMap、CollisionShape、Sprite 和 SceneTree 都不复制到 WorldState。

WorldState 是随当前游戏运行持续存在的 Autoload，以 `entity_id → EntityState` 统一保存 ActorState 与 FurnitureState，并继续独立保存 WorldTimeState。它不加载 Definition、不创建 Entity，也不解释家具行为。Scene Node 被释放不代表逻辑实体或世界事实删除：Location 重载会创建新的 Presentation，绑定 EntityRegistry 中同一 Entity 及 WorldState 中同一 State。

Location 的格子索引仍是当前已加载 Scene 的局部查询结构，不是 World State。当前运行时 WorldState 也不是磁盘存档；未来 Save / Load 应序列化这份世界事实结构，而不是建立另一套权威。当前不实现文件格式、版本迁移或存档槽。

## 统一世界时间

世界时间是世界级事实，不属于某个 Entity，也不依附当前加载的 Location Scene。WorldTimeState 与 EntityState 集合分离，当前只保存一个权威基础量 `total_minutes`。年、月、日、时、分、星期和季节全部由该值及统一日历规则推导，不作为平行字段重复保存，因而不存在多个日期字段相互失配的问题。

WorldState 持有 WorldTimeState，使它与其他运行时世界事实一样跨 Location Scene 生命周期持续存在。独立的 WorldTime 运行时服务负责解释并改变这份事实，包括帧率无关的自然流逝、按分钟推进、推进到指定未来时刻、日历换算以及变化通知。Location、HUD 和具体 Furniture 不各自维护当前时间，也不直接操作 `total_minutes`。

当前日历常量集中在同一处：一年 12 个月、每月 30 天、一周 7 天、一天 24 小时、每小时 60 分钟；第一年一月一日是 Monday，四季各覆盖连续三个月。运行时初始事实是第一年一月一日 08:00。自然时间使用小数秒累积，当前统一速率是 1 个真实秒对应 1 个游戏分钟；时间节点遵循 SceneTree 暂停，不在暂停期间自然推进。

时间服务在推进后通知总分钟变化，并分别报告跨过的分钟、绝对小时边界和绝对天边界。一次大跨度推进只需一次通知即可携带变化前后范围与跨越数量，未来消费者能够据此处理所有跨界，不必假定每次只增加一分钟。当前不在时间系统中预建事件调度器或 NPC 日程系统。

睡眠仍沿用正式 Action 链：公共空间规则和 SleepableBehavior 通过后，请求 WorldTime 推进到下一天 08:00；日期进位与跨月、跨年计算由时间服务负责。Furniture 不保存另一份日期，也不直接写 WorldTimeState。HUD 属于 Presentation，只订阅时间变化并读取派生值进行显示，不拥有或修改世界时间。

## Actor、Furniture、Behavior 与表现

Actor extends Entity，并关联 ActorDefinition 与 ActorState。ActorDefinition 当前只保存 UUID v4 `entity_id`、`display_name` 和 `visuals.up/down/left/right` 四张静态 Texture2D 路径；ActorState 在公共 EntityState 上增加四方向 `facing`。Location 加载时统一创建 ActorPresentation，从 State 恢复位置和朝向并选择对应纹理；卸载前把 Scene 中的连续位置同步回同一个 State。

Furniture extends Entity，并关联可共享的 FurnitureDefinition、实例独享的 FurnitureState 和一组轻量 Behavior。`simple_bed`、`wooden_chest`、`sign` 都是 JSON Definition，不存在 Bed、Chest、Sign 逻辑子类。SleepableBehavior、OpenableBehavior、InspectableBehavior 分别封装当前睡眠、开关与查看规则；`is_open` 属于 FurnitureState，开启视觉路径属于 Definition 配置，Behavior 对象不保存具体家具实例状态。

所有家具共用 FurniturePresentation Scene。它只绑定已有 Furniture，按 Definition / State 设置视觉、位置、占位碰撞，并把自身登记到当前 GridScene 的空间索引；它不生成 UUID，不创建或注册 Entity / State，也不判断 Action。箱子状态变化后 Presentation 只负责刷新视觉。离开酒馆会释放这些 Node，重新进入时创建的新 Presentation 会绑定原 Furniture 与原 FurnitureState，因此直接恢复开启状态。

PlayerController 独立持有当前受控 Actor 和它在已加载 Location 中的 ActorPresentation，继续负责输入、连续移动、交互意图、结果信号和 Camera。角色与 Camera 跟随在物理帧更新，并使用 2D 物理插值平滑渲染；Location 切换后 Controller 绑定同一 Actor 的新 Presentation。Actor 与 ActorPresentation 不保存 Player 类型标记，Player 只表示当前控制权。Martha ActorDefinition 数据仍可加载，但在通用 NPC 初始化出现前不创建 Runtime Entity、State 或 Presentation。

## 当前交互与行为关系

玩家按下统一交互输入时，PlayerController 请求 InteractionTargetSelector 先查询当前受控 ActorPresentation facing 方向的相邻格，再查询其当前格。查询使用当前 Location 的 FurniturePresentation 格子索引，不遍历 SceneTree；命中 Presentation 后取出逻辑 Furniture，并按稳定 `entity_id` 选择一个支持行为的 Entity 返回。这一过程只负责确定意图目标，不让家具分别监听输入，也不是 Action 合法性的唯一防线。

选中目标后的当前基础关系是：

```text
PlayerController 把玩家输入转化为移动或交互意图
  ↓
ActorPresentation 绑定 Actor、执行当前 Scene 中的空间移动并同步状态
  ↓
Location / GridScene 维护自身格子中的 FurniturePresentation
  ↓
InteractionTargetSelector 从 Presentation 命中取得逻辑 Entity
  ↓
WorldAction 表达逻辑 Actor、行为身份和 Entity 目标
  ↓
公共空间规则验证同一 Location 与当前格 / facing 相邻格
  ↓
Furniture 把具体规则委派给对应 Behavior
  ↓
执行并修改 EntityState / WorldTimeState
  ↓
Presentation 根据逻辑状态更新当前表现
  ↓
ActionResult（success / failure、消息与失败代码）
  ↓
Presentation 显示结果
```

公共空间规则属于 WorldAction 执行链，依赖逻辑 EntityState 验证 Actor 与 Entity 目标有效、属于同一个 Location，并且目标占据 Actor 当前格或 facing 相邻格；通过后才进入 Furniture Behavior 的规则和执行。Scene / Physics 只参与目标命中，Action 不操作 FurniturePresentation。即使未来 NPC、AI 或其他系统绕过玩家 Selector 直接创建 WorldAction，非法空间行为也不能修改目标状态。

行为合法性判断与执行保持分离。PlayerController 只产生玩家意图并发出结果，不直接修改家具状态，也不直接更新交互结果 UI。空间拒绝同样返回正式 ActionResult 和明确失败代码。合法 open / close 修改权威 FurnitureState，Presentation 只根据同一状态更新视觉。正式结果不只服务玩家画面；未来 NPC 或 AI 发起行为时，也应能得到相同的成功、失败和原因信息。

## 世界事实的权威边界

World State 记录已经成立的世界事实，但事实不能仅凭输入、角色意图、模拟建议、表现效果或生成内容而成立。确定性的世界状态变化必须来自经过 World Rules 验证、并由游戏系统执行的结果。

玩家和 NPC 都是世界中的 Actors。当两者采取本质相同的行为时，应由同一个世界中的游戏规则判断，而不是因为控制来源不同就天然获得不同的规则权威。

World Simulation 可以推动时间并发起非玩家直接驱动的变化，但这些变化仍需遵守世界规则。它负责让世界运转，不因此获得绕过规则修改事实的权力。

## AI 的权威边界

AI 是内容与决策建议来源，不是世界权威。它可以提出角色可能采取的行动、生成开放性内容或为系统提供建议，但不能直接宣布行动成功、物品出现、角色状态改变或其他世界事实已经发生。

AI 参与世界变化时必须遵循：

```text
AI 提议 → 游戏规则验证 → 游戏系统执行 → World State 改变
```

AI 的输出即使被接受，也必须通过与该行为相适应的规则和执行过程。

## Presentation 与逻辑世界

PlayerController 负责把玩家输入转化为可供游戏处理的意图；ActorPresentation、FurniturePresentation 与其他 Presentation 负责把世界状态和行为结果呈现为 Godot 场景、画面、UI、声音及反馈。

Presentation 可以维护表现所需的临时状态，但不能把画面上看似发生的事情直接当作已经成立的世界事实。逻辑世界也不应依赖某个特定界面或验证场景才能成立。

ActorPresentation 与 FurniturePresentation 都按稳定 `entity_id` 绑定 EntityRegistry 中的逻辑 Entity，并从 WorldState 持有的同一 EntityState 恢复表现。两者都允许 Scene Node 随 Location 加载和卸载，而权威动态状态继续存在。其他 Scene 与逻辑世界的绑定只在出现真实需求时决定。

## 暂不规定的实现事项

除已由实际功能建立的当前边界外，本文不提前规定未来的类、文件、JSON Schema、Godot Node 或 Resource 选择、signal、Manager、API、存档格式和具体算法。它们应在对应需求清楚后单独设计。
