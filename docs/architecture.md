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
- Instance 持有具体 Definition Resource、独立 `instance_id` 与 State；
- Representation 是 Instance 在当前加载 Scene 中可创建、销毁和重建的临时表现。

Project Definition 使用 Godot Custom Resource 保存和引用，不维护业务 UUID。Entity 与 Location Instance 的 `instance_id` 继续使用 UUID v4，标识世界中的具体对象；EntityState 和 LocationState 不复制 Definition 身份。Actor、Furniture 和 LocationRuntime 直接持有对应的强类型 Definition Resource。

```text
ActorDefinition + ActorState → Actor → ActorRepresentation
FurnitureDefinition + FurnitureState → Furniture → FurnitureRepresentation
LocationDefinition + LocationState → LocationRuntime → GridScene Representation
```

Project Definition `.tres` 没有运行时更新入口。床损坏、家具开启、Actor 移动、地面改变或道路禁用等变化全部进入对应 State，而不修改 Definition Resource。

## Project Definition Resources

具体 Definition 都直接继承 Resource，没有公共代码基类。Godot 负责 `.tres` 的保存、加载和 Resource 间引用；业务代码不维护 Definition Registry、Resource UID 映射或 JSON Loader。

Project Definitions 当前包括：

- Player 与 Martha 的 ActorDefinition；
- Chest、Sign、Bed 的 FurnitureDefinition；
- GroundTileDefinition、DecorationTileDefinition 与 StructureTileDefinition；
- Tavern、Town Street 与 Tavern Yard 的 LocationDefinition。

ActorDefinition 直接引用四向 Texture2D；FurnitureDefinition 直接引用 Texture2D、FurnitureBehavior 子资源和 Definition-local `footprint_cells: Array[Vector2i]`；ActorDefinition 与 FurnitureDefinition 都可以保存强类型 UseSlot Resource。Furniture footprint 只保留这份局部 Cell 集合，不再同时维护矩形尺寸。LocationDefinition 的三个 Cell Layer 直接引用 TileDefinition `.tres`。`project_world.tres` 只保存现有 Project Location instance spec：项目键、Instance UUID 与 LocationDefinition Resource。

## Location 的正式组成

Location 是世界实例，不是 Scene。LocationRuntime 组合 LocationDefinition Resource、LocationState 与 EntityRegistry，向消费者提供当前有效查询。

```text
Location
├─ Topology
├─ Spatial Layout
│  ├─ Ground Layer
│  ├─ Decoration Layer
│  ├─ Structure Layer
│  ├─ Entries
│  └─ Exits
└─ Entities（由 EntityState 派生）
```

当前三个 Project Location 实例使用独立 UUID，并各自直接引用 LocationDefinition `.tres`。项目键 `tavern`、`town_street` 与 `tavern_yard` 只用于项目启动配置，不是运行时世界身份。

### Topology

Topology 延续有向 Location Graph。每条 LocationEdgeDefinition 保存：

- 全局稳定的 `edge_id` UUID；
- 所属 Location 内可读且唯一的 `edge_key`；
- 目标 Location Instance UUID `target_location_id`；
- 目标地点内的 `target_entry_id`。

边不重复保存来源 Location，也不保存目标 Entry 的局部坐标。双向通行由两条有向边分别表达。

### Ground Layer

Ground Layer 的权威形式是 `cell → GroundTileDefinition Resource`。GroundTileDefinition 保存通行规则、移动成本，以及固定 World TileSet 中的 `source_id`、`atlas_coords` 和 `alternative_tile`。Grass、Road、Wood Floor 等内容各自是独立 `.tres`，Location Cell 直接引用它们。

### Decoration Layer

Decoration Layer 的权威形式是 `cell → DecorationTileDefinition Resource`。DecorationTileDefinition 只选择固定 World TileSet 中的装饰 Tile；当前项目没有真实 Decoration Tile，因此三处 Location 的这一层为空。地点名称等文字不属于 Decoration Layer。需要独立状态、采集、破坏、任务引用或交互的内容必须成为 Entity。

### Structure Layer

Structure Layer 的权威形式是 `cell → StructureTileDefinition Resource`。StructureTileDefinition 保存逻辑阻挡，并选择固定 World TileSet 中的具体 Tile。连续墙体直接记录为多个 Cell；当前双格门洞由左右两个 StructureTileDefinition `.tres` 分别占据一格，不存在额外的对象身份或 footprint 展开。

### Entries 与 Exits

LocationEntry 直接保存 `entry_id`、Cell 与 Facing。Topology 只指出目标 Entry ID；LocationEntry 拥有该 Entry 在目标 Location 内的格子位置和朝向，切换落点由 Cell 原点确定。

LocationExit 直接保存对应的 `edge_key` 与本地 Cell Rect。SceneBuilder 根据它创建临时的 LocationExitArea 触发区域；Topology 继续独立负责该 Edge 连接到哪个 Location。

### Entities

Entity 所属 Location 与位置的唯一持久真相是：

- `EntityState.current_location_id`；
- `EntityState.local_position`。

LocationState 不保存 `entity_ids` 或 `entity_positions`。LocationRuntime 通过 EntityRegistry 查询 `current_location_id == instance_id` 的 Entity，并可按 Entity footprint 派生 Cell 查询。未来如增加 Location 或 Cell 索引，它们也必须能从 EntityState 重建，不能成为第二份 Save Truth。

## LocationState Sparse Overrides

LocationState 只保存与 LocationDefinition 不同的部分：

- `ground_overrides`；
- `decoration_overrides`；
- `structure_overrides`；
- `removed_edge_ids`、`disabled_edge_ids` 与 `added_edges`。

三层 Cell override 都使用 `cell → TileDefinition Resource`；`null` 明确表示当前 Cell 为空。没有变化的 LocationState 不复制完整 Ground、Structure、Decoration 或 Topology。LocationRuntime 负责把 Definition 基础数据与 Sparse Overrides 合并为当前三层 Cell 数据和 Topology 结果，其他系统不各自解释覆盖规则。

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

LocationSceneBuilder 只消费 LocationRuntime 已合并出的当前 Ground、Decoration、Structure Cell Layer，以及直接的 Entries / Exits，并逐层创建静态空间和切换节点。它不按具体 Entity 类型创建 Actor 或 Furniture Node；Entity 表现仍由 V8 的 EntityRepresentationRegistry 与唯一匹配的 EntityRepresentationFactory 准备。三个 Tile Layer 使用固定 World TileSet，具体 TileDefinition 只保存 Tile 选择字段。

现有 Tavern、Town Street 与 Tavern Yard 的静态入口位于 `data/world/project_world.tres`，并直接引用 `data/locations/` 中的三个 LocationDefinition Resource。三份固定地图 `.tscn` 已删除；LocationDefinition 没有 `scene_path`，Game 也不加载地点 PackedScene。SceneTree、TileMapLayer、Collision 与 Marker 都是可丢弃的下游表现。

离开 Location 会销毁 GridScene 及其中的 Entity Representations，但不会删除 LocationDefinition、LocationState、Entity 或 EntityState。再次进入时，系统从当前 LocationRuntime 完整重建 Scene，并让 Factory 把已有 Entity 绑定到新的 Representation。

本架构没有 Scene → Authoring → Baking → World Data 路线，也没有 fingerprint、bake cache、preflight、Scene Placement Baking 或 Location Baking。项目世界数据直接位于 Scene 上游。

## Location Prepare → Commit

动态 Scene 生成继续服从失败安全的 Prepare → Commit：

```text
Prepare
├─ 解析目标 LocationRuntime
├─ 验证目标 LocationEntry
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

Prepare 不修改正式 EntityState，不释放旧 Scene，不改变 PlayerController 或活动 Location。Spatial Tile、Entry、Factory 或 Representation 准备失败时，只释放临时目标树，旧世界仍可操作。Commit 不再加载或验证资源。

## Entity 与 Entity Representation

Entity 是拥有独立 UUID `instance_id`、Definition Resource 引用和独立 State 的逻辑对象。当前大类是 Actor 与 Furniture，这不是封闭列表。EntityRegistry 按 instance UUID 统一登记和查询，不按具体子类分支；注册时检查 Instance UUID、State 与非空 Definition Resource。EntityRegistry 不解析或登记 Definition。

Entity 大类表达根本结构或生命周期差异；Definition 表达具体内容是什么；Behavior / Component 表达能做什么；BehaviorState 保存可组合能力的实例变化。Bed、Chest、Sign 不建立逻辑子类，而由 FurnitureDefinition 与 Sleepable、Openable、Inspectable Behavior 组合表达。只有 Openable 当前需要独立 OpenableState。

Representation 依赖 Entity，Entity 不依赖 Representation。ActorRepresentation 继续使用 CharacterBody2D，FurnitureRepresentation 继续使用 Node2D；统一的是 Factory 创建协议和逻辑绑定，而不是强迫所有表现继承同一个 Node 基类。

EntityRepresentationRegistry 扫描全部 Factory 并要求恰好一个匹配。零匹配或多匹配都使 Location Prepare 失败。Game 不按 Actor / Furniture 类型分支，也不持有具体 Entity Representation Scene。

## Entity Interaction Space

UseSlot 是 Entity Definition 中某个 Action 的理论执行位置。每项保存 Entity 局部格 `local_cell`、允许的 Actor 朝向 bitmask `allowed_facings`、`supported_actions` 与零到多个 SlotEntrance Resource。`allowed_facings == 0` 表示允许全部正常朝向，非零 bitmask 可以表达一个或多个明确方向。局部格原点固定为 Entity footprint 左上角 `(0, 0)`；UseSlot 可以位于 footprint 内部或外部。EntityState 移动时 Definition 坐标不变。

某个 Action 只要存在至少一个显式 UseSlot，就只使用这些显式项。没有显式项时，Entity 根据 Definition-local footprint Cell 集合派生临时默认 UseSlot，但不写回或修改 Definition：每个 footprint Cell 的上下左右邻格只要位于 footprint 外就成为外部 Slot，按 local Cell 去重，并把同一位置来自多个 footprint Cell 的合法方向合并到同一个 `allowed_facings`，不产生对角 Slot。外部 Slot 的方向分别对应左侧 RIGHT、右侧 LEFT、上侧 DOWN、下侧 UP；non-blocking Entity 还为每个 footprint Cell 生成允许全部正常朝向的脚下 Slot；blocking Entity 不生成脚下默认 Slot。Furniture 的不规则 footprint（例如 `(0,0)、(1,0)、(0,1)`）按真实 Cell 集合处理。

SlotEntrance 是具体 UseSlot 的进入位置，也使用同一个 Entity 局部格原点。显式配置时完整保留全部 SlotEntrance；没有显式配置时，查询返回一个 `local_cell == UseSlot.local_cell` 的默认 Entrance。Entrance 不按 footprint 或 facing 推断其他位置。

职责边界固定为：

```text
Entity Definition
└─ footprint + UseSlot[] + SlotEntrance[]
        ↓ 与 EntityState 当前位置组合
LocationRuntime
└─ world Cell 转换 + bounds / Ground / Structure / Entity blocking 校验
        ↓
PlayerController + ActionSpatialRule
```

Furniture 直接从 Definition-local footprint Cell 集合计算占用 world Cell，并由 Entity 当前 footprint origin 加上各自 `local_cell` 转换 UseSlot 与 SlotEntrance。FurnitureRepresentation 的 Physics collision 也只从同一份 `footprint_cells` 派生：每个 occupied local Cell 创建一个完整 `GridSpace.CELL_SIZE × GridSpace.CELL_SIZE` 的 RectangleShape2D，按 Cell 中心定位；不使用 bounding rectangle、不做 4px 内缩、不维护第二份 collision footprint 数据。non-blocking Furniture 保留对应 shape 但将其禁用。LocationRuntime 不生成、删除或修改 Definition，只复用当前 Ground、Structure 与 Entity 查询验证可用性。UseSlot 位于目标 Entity footprint 内时会忽略目标自身的 blocking，但仍检查 Ground、Structure 和其他 blocking Entity；SlotEntrance 必须是普通 Actor 当前可站立的 Cell。Definition 是否存在与当前是否可用是两件事。

## Action、Interaction 与移动

PlayerController 把输入转化为移动或交互意图。ActorRepresentation 在当前 Scene 中执行连续物理移动并把位置同步回 ActorState。PlayerController 直接从当前 LocationRuntime 查询 Entity，按 Actor 当前 Cell、facing、Action UseSlot 和当前 Runtime 有效性选择候选；有明确方向限制且当前 facing 被允许的 Slot 优先于 unrestricted Slot，完全同级时按稳定 instance UUID 排序。Representation、Scene 索引和物理节点都不是交互目标的逻辑来源。

WorldAction 使用逻辑 EntityState 验证同一 Location，然后由 ActionSpatialRule 要求 Actor 当前 Cell 匹配至少一个当前有效、朝向正确的 Action UseSlot。没有 LocationRuntime 时直接 reject，不再使用仅检查 Slot/facing 的 fallback。旧的“目标位于脚下或面前”判断已删除；默认 UseSlot 保留相同体验，并成为唯一交互空间权威。Entity 默认拒绝 Action 并默认不阻挡移动；Furniture 把具体检查与执行委派给 Behavior，并按 FurnitureDefinition 提供统一的移动阻挡结果。合法结果修改 EntityState 或 WorldTimeState；Representation 只刷新视觉。

## 世界时间

WorldTimeState 是独立于 Entity 与 Location Scene 的世界级事实，只保存 `total_minutes`。年月日、时分、星期与季节由统一日历规则推导。WorldTime Runtime 负责帧率无关的推进与变化通知；HUD 只订阅并显示。

睡眠沿正式 Action 链推进到下一天 08:00。Furniture 不保存另一份时间，也不直接修改 UI。

## 暂不规定的事项

当前不实现 Location Editor、Dungeon / Town PCG、AI、Schedule、Goal、Behavior Tree、NPC Navigation、Pathfinding、SIPP、Reservation、Slot 占用预订、自动前往 SlotEntrance、从 Entrance 进入 UseSlot、坐下、躺下、动画、多人避让、Ownership、Home / Workplace、复杂地图破坏或完整 Save / Load 重构。当前不为这些方向预建 Manager、Registry、状态或移动流程；出现真实消费者后再设计。
