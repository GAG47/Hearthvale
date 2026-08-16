# Hearthvale 软件架构

## 文档目的

本文描述当前已经落地的职责边界和世界事实流。它不预先规定尚无消费者的系统，也不把代码目录或 Godot Node 结构误当作领域模型。

## 世界事实与规则

World State 记录已经成立的动态事实；World Rules 判断行为是否合法并产生确定结果；Action / Interaction 表达 Actor 的意图；Scene、UI 和其他 Representation 只呈现逻辑世界。玩家、NPC、模拟或 AI 都不能绕过规则直接宣布世界事实成立。

```text
变化来源
  ↓
Action / Interaction
  ↓
World Rules
  ↓
执行确定结果
  ↓
World State
  ↓
Representation / UI
```

AI 可以生成内容或提出行动建议，但不拥有规则权威。AI 输出仍必须经过同一条验证、执行和 State 修改链。

## Definition、State、Instance 与 Representation

所有长期存在的世界对象遵守同一组概念：

- Definition 是实例生命周期内稳定不变的规格数据；
- State 是某个具体实例在世界运行中会变化的数据；
- Instance 由独立的 `definition_id`、`instance_id` 与 State 构成；
- Representation 是 Instance 在当前加载 Scene 中可创建、销毁和重建的临时表现。

`definition_id` 与 `instance_id` 都使用 UUID v4，但语义严格不同。Definition UUID 标识一份规格；Instance UUID 标识世界中的一个具体对象。Actor、Furniture 和 Location 的 State 都显式保存 `definition_id` 与 `instance_id`，Runtime Instance 必须使用 DefinitionRegistry 中对应的 Definition 对象。

```text
ActorDefinition + ActorState → Actor → ActorRepresentation
FurnitureDefinition + FurnitureState → Furniture → FurnitureRepresentation
LocationDefinition + LocationState → LocationRuntime → generated GridScene
```

Definition 创建并进入 Registry 后没有运行时更新入口。床损坏、家具开启、Actor 移动、地面改变或道路禁用等变化全部进入对应 State，而不修改 Definition。

## DefinitionRegistry

DefinitionRegistry 是 `definition_id → Definition` 的唯一运行时解析入口。Project Definition 和 Generated Definition 只在生产、首次加载与持久化阶段不同；注册完成后，查询、模拟、SceneBuilder、Entity 和交互系统都通过同一个 Registry 取得 Definition，不分叉运行逻辑。

Project Definitions 当前包括：

- Player 与 Martha 的 ActorDefinition；
- Chest、Sign、Bed 的 FurnitureDefinition；
- GroundDefinition、DecorationDefinition 与 StructureDefinition；
- Tavern、Town Street 与 Tavern Yard 的 LocationDefinition。

Generated Definition 使用同一 UUID 命名空间和同一注册校验。Registry 可以把 Generated Definitions 序列化为完整 Definition 数据并恢复。未来生成器应直接产生 LocationDefinition，分配 Definition UUID，注册后创建 LocationState；不能先生成临时 Scene 再反向转换为世界数据。

正式恢复依赖持久化的 Generated Definition 本身，而不是只依赖 generator seed。未来可以附带 generator ID、版本和 seed 作为来源信息，但算法变化不能改变旧世界已经生成的结果。

## Location 的正式组成

Location 是世界实例，不是 Scene。LocationRuntime 组合 LocationDefinition、LocationState、DefinitionRegistry 与 EntityRegistry，向消费者提供当前有效查询。

```text
Location
├─ Topology
├─ Spatial Layout
│  ├─ Ground Layer
│  ├─ Decoration Layer
│  ├─ Structure Layer
│  └─ Anchors
└─ Entities（由 EntityState 派生）
```

当前三个 Project Location 实例使用独立 UUID，并各自引用 LocationDefinition UUID。项目键 `tavern`、`town_street` 与 `tavern_yard` 只用于项目启动配置，不是运行时世界身份。

### Topology

Topology 延续有向 Location Graph。每条 LocationEdgeDefinition 保存：

- 全局稳定的 `edge_id` UUID；
- 所属 Location 内可读且唯一的 `edge_key`；
- 目标 Location Instance UUID `target_location_id`；
- 目标地点内的 `target_entry_id`。

边不重复保存来源 Location，也不保存目标 Entry 的局部坐标。双向通行由两条有向边分别表达。

### Ground Layer

Ground Layer 的权威形式是 `cell → ground_definition_id`。GroundDefinition 保存通行规则、移动成本以及 SceneBuilder 需要的集中表现规格。Grass、Road、Wood Floor 等内容由不同数据表达，不建立不同代码类，也不在每个 Cell 重复规格字段。

### Decoration Layer

DecorationPlacement 表示没有独立世界身份和 State 的装饰内容。它引用 DecorationDefinition，并保存 placement UUID、Cell 与局部偏移。当前地图文字标识也沿用这条数据路径。需要独立状态、采集、破坏、任务引用或交互的内容必须升级为 Entity。

### Structure Layer

StructurePlacement 表示属于 Location 空间但没有独立世界身份的静态结构。StructureDefinition 保存逻辑阻挡、`occupied_cells` footprint 与逐 footprint Cell 的表现规格；Placement 保存 placement UUID、Definition UUID、`origin_cell` 与 orientation。

所有 Structure，包括 1×1 Structure，都使用同一套 Placement 和 footprint 计算。当前双格门洞由同一 StructureDefinition 的两个 occupied cells 表达。具有独立 HP、状态、引用或交互的墙、门或设施应成为 Entity，不能继续留在 Structure。

### Anchors

Entry Anchor 保存 `entry_id`、Cell、Facing 与从 Cell 原点计算表现落点所需的局部偏移。Topology 只指出目标 Entry ID；Anchor 才拥有该 Entry 在目标 Location 内的位置和朝向。

当前 Location 切换还需要本地出口触发区域，因此存在直接消费者明确的 Exit Anchor：它保存 `edge_key` 与局部 Cell Rect，由 SceneBuilder 创建 LocationExit。没有消费者的其他 Anchor 类型不会提前加入。

### Entities

Entity 所属 Location 与位置的唯一持久真相是：

- `EntityState.current_location_id`；
- `EntityState.local_position`。

LocationState 不保存 `entity_ids` 或 `entity_positions`。LocationRuntime 通过 EntityRegistry 查询 `current_location_id == instance_id` 的 Entity，并可按 Entity footprint 派生 Cell 查询。未来如增加 Location 或 Cell 索引，它们也必须能从 EntityState 重建，不能成为第二份 Save Truth。

## LocationState Sparse Overrides

LocationState 只保存与 LocationDefinition 不同的部分：

- `ground_overrides`；
- `removed_structure_ids` 与 `added_structures`；
- `removed_decoration_ids` 与 `added_decorations`；
- `removed_edge_ids`、`disabled_edge_ids` 与 `added_edges`。

没有变化的 LocationState 不复制完整 Ground、Structure、Decoration 或 Topology。LocationRuntime 负责把 Definition 基础数据与 Sparse Overrides 合并为当前 Ground、Structure、Decoration 和 Topology 结果，其他系统不各自解释覆盖规则。

WorldState 持久持有 LocationState、EntityState 与 WorldTimeState。当前 Scene 节点注册表只记录活动 Representation 的弱引用，不是世界事实。

## Scene 是 Location Representation

V9 的数据方向固定为：

```text
LocationDefinition + LocationState + current Entities
  ↓
LocationRuntime
  ↓
LocationSceneBuilder
  ↓
GridScene
├─ GroundLayer
├─ DecorationLayer
├─ StructureLayer
├─ EntryPoints / Exit triggers
└─ EntityRepresentationRoot
```

LocationSceneBuilder 从 GroundDefinition、DecorationDefinition 与 StructureDefinition 读取逻辑及表现规格，逐层创建静态空间。它不按具体 Entity 类型创建 Actor 或 Furniture Node；Entity 表现仍由 V8 的 EntityRepresentationRegistry 与唯一匹配的 EntityRepresentationFactory 准备。

现有 Tavern、Town Street 与 Tavern Yard 的世界事实已迁移到 `data/world/project_world.json`。三份固定地图 `.tscn` 已删除；LocationDefinition 没有 `scene_path`，Game 也不加载地点 PackedScene。SceneTree、TileMapLayer、Collision 与 Marker 都是可丢弃的下游表现。

离开 Location 会销毁 GridScene 及其中的 Entity Representations，但不会删除 LocationDefinition、LocationState、Entity 或 EntityState。再次进入时，系统从当前 LocationRuntime 完整重建 Scene，并让 Factory 把已有 Entity 绑定到新的 Representation。

本架构没有 Scene → Authoring → Baking → World Data 路线，也没有 fingerprint、bake cache、preflight、Scene Placement Baking 或 Location Baking。项目世界数据和未来 Generator 直接位于 Scene 上游。

## Location Prepare → Commit

动态 Scene 生成继续服从失败安全的 Prepare → Commit：

```text
Prepare
├─ 解析目标 LocationRuntime
├─ 验证目标 Entry Anchor
├─ 从当前 Location 数据生成全部静态层
├─ 通过 EntityRepresentationRegistry 准备全部 Entity Representations
├─ 验证 PlayerController 可接管目标 ActorRepresentation
└─ 预检目标 Scene 可注册
        ↓ 全部成功
Commit
├─ 同步旧 ActorRepresentation 的最终位置
├─ 修改迁移 ActorState 的 Location、位置与 Entry Facing
├─ 激活已经准备完成的目标 Scene
├─ PlayerController 换绑 Representation
├─ 更新 Camera 与 HUD
└─ 释放旧 Scene
```

Prepare 不修改正式 EntityState，不释放旧 Scene，不改变 PlayerController 或活动 Location。Ground / Structure 表现资源、Entry、Factory 或 Representation 准备失败时，只释放临时目标树，旧世界仍可操作。Commit 不再加载或验证资源。

## Entity 与 Entity Representation

Entity 是拥有独立 UUID `instance_id`、Definition 引用和独立 State 的逻辑对象。当前大类是 Actor 与 Furniture，这不是封闭列表。EntityRegistry 按 instance UUID 统一登记和查询，不按具体子类分支；注册时检查 Instance UUID、Definition UUID、State 链接与 DefinitionRegistry 对象一致性。

Entity 大类表达根本结构或生命周期差异；Definition 表达具体内容是什么；Behavior / Component 表达能做什么；BehaviorState 保存可组合能力的实例变化。Bed、Chest、Sign 不建立逻辑子类，而由 FurnitureDefinition 与 Sleepable、Openable、Inspectable Behavior 组合表达。只有 Openable 当前需要独立 OpenableState。

Representation 依赖 Entity，Entity 不依赖 Representation。ActorRepresentation 继续使用 CharacterBody2D，FurnitureRepresentation 继续使用 Node2D；统一的是 Factory 创建协议和逻辑绑定，而不是强迫所有表现继承同一个 Node 基类。

EntityRepresentationRegistry 扫描全部 Factory 并要求恰好一个匹配。零匹配或多匹配都使 Location Prepare 失败。Game 不按 Actor / Furniture 类型分支，也不持有具体 Entity Representation Scene。

## Action、Interaction 与移动

PlayerController 把输入转化为移动或交互意图。ActorRepresentation 在当前 Scene 中执行连续物理移动并把位置同步回 ActorState。InteractionTargetSelector 使用当前 GridScene 的 FurnitureRepresentation Cell 索引命中表现，再取得逻辑 Entity 交给 WorldAction。

WorldAction 使用逻辑 EntityState 验证同一 Location 和邻接空间，之后调用 Entity 的 Action 协议。Entity 默认拒绝，Furniture 把具体检查与执行委派给 Behavior。合法结果修改 EntityState 或 WorldTimeState；Representation 只刷新视觉。NPC 或其他系统未来直接创建同类 Action 时必须经过相同规则。

## 世界时间

WorldTimeState 是独立于 Entity 与 Location Scene 的世界级事实，只保存 `total_minutes`。年月日、时分、星期与季节由统一日历规则推导。WorldTime Runtime 负责帧率无关的推进与变化通知；HUD 只订阅并显示。

睡眠沿正式 Action 链推进到下一天 08:00。Furniture 不保存另一份时间，也不直接修改 UI。

## 暂不规定的事项

当前不实现 Location Editor、真正 Dungeon / Town PCG、AI、Schedule、Goal、Behavior Tree、NPC Navigation、SIPP、Reservation、多人避让、Use Slot、Ownership、Home / Workplace、复杂地图破坏或完整 Save / Load 重构。出现真实消费者后再设计对应结构。
