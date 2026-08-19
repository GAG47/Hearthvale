# Hearthvale 软件架构

## 文档目的

本文描述当前已经落地的职责边界和世界事实流。它不预先规定尚无消费者的系统，也不把代码目录或 Godot Node 结构误当作领域模型。

## 世界事实与规则

State 记录已经成立的动态事实；规则判断行为是否合法并产生确定结果；Action / Interaction 表达 Actor 的意图；Scene、UI 和其他 Representation 只呈现逻辑世界。玩家、NPC、模拟或 AI 都不能绕过规则直接宣布世界事实成立。

```text
变化来源
  ↓
Action / Interaction
  ↓
Rules
  ↓
执行确定结果
  ↓
State
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

Project Definition 使用 Godot Custom Resource 保存和引用，不维护业务 UUID。Entity 与 Location Instance 的 `instance_id` 继续使用 UUID v4，标识世界中的具体对象；EntityState 和 LocationState 不复制 Definition 身份。Actor、Furniture 和 Location 直接持有对应的强类型 Definition Resource。

```text
ActorDefinition + ActorState → Actor → ActorRepresentation
FurnitureDefinition + FurnitureState → Furniture → FurnitureRepresentation
LocationDefinition + LocationState + EntityRegistry → Location
Location → LocationSceneBuilder → LocationScene
```

Project Definition `.tres` 没有运行时更新入口。床损坏、家具开启、Actor 移动、地面改变或道路禁用等变化全部进入对应 State，而不修改 Definition Resource。

## Project Definition Resources

具体 Definition 都直接继承 Resource，没有公共代码基类。Godot 负责 `.tres` 的保存、加载和 Resource 间引用；业务代码不维护 Definition Registry、Resource UID 映射或 JSON Loader。

Project Definitions 当前包括：

- Player 与 Martha 使用的 ActorDefinition，其中 `move_speed` 决定 Logical Movement 单格 Step 的 duration；
- Chest、Sign、Bed 的 FurnitureDefinition；
- GroundTileDefinition、DecorationTileDefinition 与 StructureTileDefinition；
- Tavern、Town Street 与 Tavern Yard 的 LocationDefinition。

ActorDefinition 直接引用四向 Texture2D；FurnitureDefinition 直接引用 Texture2D、FurnitureBehavior 子资源和 Definition-local `footprint_cells: Array[Vector2i]`；ActorDefinition 与 FurnitureDefinition 都可以保存强类型 UseSlot Resource。Furniture footprint 只保留这份局部 Cell 集合，不再同时维护矩形尺寸。LocationDefinition 的三个 Cell Layer 直接引用 TileDefinition `.tres`。`project_world.tres` 只保存现有 Project Location instance spec：项目键、Instance UUID 与 LocationDefinition Resource。

## Location 的正式组成

Location 是世界实例，不是 Scene。Location 组合 LocationDefinition Resource、LocationState 与 EntityRegistry，向消费者提供当前有效查询。

正式依赖方向固定为：

```text
LocationDefinition + LocationState + EntityRegistry
  ↓
Location
  ↓
LocationSceneBuilder
  ↓
LocationScene
```

Location 只持有这三个逻辑依赖。LogicalMovement 不属于 Location；Location 不读取 Movement Request、tail/head/phase、priority inheritance 或 transient Actor occupancy。

```text
Location
├─ Topology
├─ Spatial Layout
│  ├─ Ground Layer
│  ├─ Decoration Layer
│  ├─ Structure Layer
│  ├─ Entries（有序 arrival Cells）
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

LocationEntry 直接保存 `entry_id`、有序 `arrival_cells` 与 Facing。Topology 只指出目标 Entry ID；LocationEntry 拥有该 Entry 在目标 Location 内的候选格子位置和朝向。Location Transfer 的 Prepare 阶段按 Definition 顺序选择首个静态可进入、且没有 Actor hard occupancy 的 Cell，全部候选不可用时直接拒绝，Commit 不再依赖 Scene Physics 修正重叠。requesting head 只是意图，不会形成 Entry 空气墙。现有单 Cell Entry 迁移为只含一个元素的数组，因此原有落点顺序保持不变。

LocationExit 直接保存对应的 `edge_key` 与本地 Cell Rect。SceneBuilder 根据它创建临时的 LocationExitArea 触发区域；Topology 继续独立负责该 Edge 连接到哪个 Location。

### Entities

Entity 所属 Location 与位置的唯一持久真相是：

- `EntityState.current_location_id`；
- `EntityState.local_cell: Vector2i`。

Location Logical World 的正式空间单位只有 Grid Cell。`Entity.current_cell` 直接返回 `state.local_cell`，语义是 Entity 已经提交的稳定逻辑 Cell，不再从 Scene 或像素 `Vector2` 反推。LocationState 不保存 `entity_ids` 或 `entity_positions`。Location 通过 EntityRegistry 查询 `current_location_id == instance_id` 的 Entity；`get_entities_at(cell)` 只使用 Entity 的 committed `local_cell` / footprint。extended Actor 的 State 仍在 tail，因此 Location 只在 tail 查到它，不会在 head 提前查到它。完整 `{tail, head}` hard occupancy 只由 LogicalMovement 查询。Location Entity Position 与 LogicalMovement transient occupancy 是两种不同事实。

## LocationState Sparse Overrides

LocationState 只保存与 LocationDefinition 不同的部分：

- `ground_overrides`；
- `decoration_overrides`；
- `structure_overrides`；
- `removed_edge_ids`、`disabled_edge_ids` 与 `added_edges`。

三层 Cell override 都使用 `cell → TileDefinition Resource`；`null` 明确表示当前 Cell 为空。没有变化的 LocationState 不复制完整 Ground、Structure、Decoration 或 Topology。Location 负责把 Definition 基础数据与 Sparse Overrides 合并为当前三层 Cell 数据和 Topology 结果，其他系统不各自解释覆盖规则。

StateRegistry 只登记、持有和查询 LocationState、EntityState 与 GameTimeState。它不自动决定 Project LocationState 的创建，也不保存 LocationScene Node 或活动 Scene 弱引用；当前活动 LocationScene 由 Game 的 `current_location` 持有。

## LocationRegistry

LocationRegistry 按 Location instance UUID 登记和查询当前逻辑 Location，提供 `register`、`has`、`get` 与 `get_all` 语义。当前 ProjectWorld 的 project key → instance UUID 只作为启动期 lookup alias，不是第二份 Definition 权威。Location Definition 数据校验和 ProjectWorld 索引暂由 LocationRegistry 承接；Edge / Entry 的当前查询由 Location 本身负责，Registry 只做跨 Location 查找和委托。

## Scene 是 Location Representation

当前数据方向固定为：

```text
LocationDefinition + LocationState + EntityRegistry
  ↓
Location
  ↓
LocationSceneBuilder
  ↓
LocationScene
├─ GroundLayer
├─ DecorationLayer
├─ StructureLayer
├─ EntryPoints / Exit triggers
└─ EntityRepresentationRoot
```

LocationSceneBuilder 只消费 Location 已合并出的当前 Ground、Decoration、Structure Cell Layer，以及直接的 Entries / Exits，并逐层创建静态空间和切换节点。它不按具体 Entity 类型创建 Actor 或 Furniture Node；Entity 表现仍由 V8 的 EntityRepresentationRegistry 与唯一匹配的 EntityRepresentationFactory 准备。三个 Tile Layer 使用固定 World TileSet，具体 TileDefinition 只保存 Tile 选择字段。

现有 Tavern、Town Street 与 Tavern Yard 的静态入口位于 `data/world/project_world.tres`，并直接引用 `data/locations/` 中的三个 LocationDefinition Resource。三份固定地图 `.tscn` 已删除；LocationDefinition 没有 `scene_path`，Game 也不加载地点 PackedScene。SceneTree、TileMapLayer、Collision 与 Marker 都是可丢弃的下游表现。一个 Entry 有多个 arrival Cell 时，SceneBuilder 可以为调试和表现创建多个 Marker，但 Marker 不参与落点合法性判断。

离开 Location 会销毁 LocationScene 及其中的 Entity Representations，但不会删除 LocationDefinition、LocationState、Entity 或 EntityState。再次进入时，系统从当前 Location 完整重建 Scene，并让 Factory 把已有 Entity 绑定到新的 Representation。

本架构没有 Scene → Authoring → Baking → World Data 路线，也没有 fingerprint、bake cache、preflight、Scene Placement Baking 或 Location Baking。项目世界数据直接位于 Scene 上游。

## Location Prepare → Commit

动态 Scene 生成继续服从失败安全的 Prepare → Commit：

```text
Prepare
├─ 解析目标 Location
├─ 验证目标 LocationEntry
├─ 由 Location 检查 arrival Cell 的静态合法性
├─ 由 LogicalMovement 检查 Actor hard occupancy
├─ 从当前 Location 数据生成全部静态层
├─ 通过 EntityRepresentationRegistry 准备全部 Entity Representations
├─ 验证 PlayerController 可接管目标 ActorRepresentation
└─ 验证目标 LocationScene 与逻辑 Location 身份一致
        ↓ 全部成功
Commit
├─ 确认迁移 Actor 已完成当前逻辑单步
├─ 修改迁移 ActorState 的 Location、local_cell 与 Entry Facing
├─ 激活已经准备完成的目标 Scene
├─ PlayerController 换绑 Representation
├─ 更新 Camera 与 HUD
└─ 释放旧 Scene
```

Prepare 不修改正式 EntityState，不释放旧 Scene，不改变 PlayerController 或活动 Location。Spatial Tile、Entry、Factory 或 Representation 准备失败时，只释放临时目标树，旧世界仍可操作。Commit 不再加载或验证资源。

## Entity 与 Entity Representation

Entity 是拥有独立 UUID `instance_id`、Definition Resource 引用和独立 State 的逻辑对象。当前大类是 Actor 与 Furniture，这不是封闭列表。EntityRegistry 按 instance UUID 统一登记和查询，不按具体子类分支；注册时检查 Instance UUID、State 与非空 Definition Resource。EntityRegistry 不解析或登记 Definition。

Entity 大类表达根本结构或生命周期差异；Definition 表达具体内容是什么；Behavior / Component 表达能做什么；BehaviorState 保存可组合能力的实例变化。Bed、Chest、Sign 不建立逻辑子类，而由 FurnitureDefinition 与 Sleepable、Openable、Inspectable Behavior 组合表达。只有 Openable 当前需要独立 OpenableState。

Representation 依赖 Entity，Entity 不依赖 Representation。ActorRepresentation 继续使用 CharacterBody2D，FurnitureRepresentation 继续使用 Node2D；统一的是 Factory 创建协议和逻辑绑定，而不是强迫所有表现继承同一个 Node 基类。EntityRepresentationFactory 接收目标 Cell，不接收逻辑 pixel position。ActorRepresentation 每个 physics frame 从 Actor 的 committed Cell、Movement tail/head/progress 与 facing 计算 Scene 表现；PlayerController 不能把 Representation 位置回写到 ActorState。EntityState.local_cell 是 Player、NPC 与 Furniture 共用的唯一正式位置权威，Representation 销毁或 Scene 卸载不会反写旧坐标。

EntityRepresentationRegistry 扫描全部 Factory 并要求恰好一个匹配。零匹配或多匹配都使 Location Prepare 失败。Game 不按 Actor / Furniture 类型分支，也不持有具体 Entity Representation Scene。

## Entity Interaction Space

UseSlot 是 Entity Definition 中某个 Action 的理论执行位置。每项保存 Entity 局部格 `local_cell`、标准方向 bitmask `allowed_facings`、`supported_actions` 与零到多个 SlotEntrance Resource。`allowed_facings == 0` 表示不允许任何正常朝向；单 bit 表示单方向，多 bit 表示方向集合；`UseSlot.ALL_FACINGS`（UP | DOWN | LEFT | RIGHT）表示 unrestricted。局部格原点固定为 Entity footprint 左上角 `(0, 0)`；UseSlot 可以位于 footprint 内部或外部。EntityState 移动时 Definition 坐标不变。

某个 Action 只要存在至少一个显式 UseSlot，就只使用这些显式项。没有显式项时，Entity 根据 Definition-local footprint Cell 集合派生临时默认 UseSlot，但不写回或修改 Definition：每个 footprint Cell 的上下左右邻格只要位于 footprint 外就成为外部 Slot，按 local Cell 去重，并把同一位置来自多个 footprint Cell 的合法方向合并到同一个 `allowed_facings`，不产生对角 Slot。外部 Slot 的方向分别对应左侧 RIGHT、右侧 LEFT、上侧 DOWN、下侧 UP；non-blocking Entity 还为每个 footprint Cell 生成 `UseSlot.ALL_FACINGS` 的脚下 Slot；blocking Entity 不生成脚下默认 Slot。Furniture 的不规则 footprint（例如 `(0,0)、(1,0)、(0,1)`）按真实 Cell 集合处理。

SlotEntrance 是具体 UseSlot 的进入位置，也使用同一个 Entity 局部格原点。显式配置时完整保留全部 SlotEntrance；没有显式配置时，查询返回一个 `local_cell == UseSlot.local_cell` 的默认 Entrance。Entrance 不按 footprint 或 facing 推断其他位置。

职责边界固定为：

```text
Entity Definition
└─ footprint + UseSlot[] + SlotEntrance[]
        ↓ 与 EntityState 当前位置组合
Location
└─ world Cell 转换 + bounds / Ground / Structure / Entity blocking 校验
        ↓
PlayerController + ActionSpatialRule
```

Furniture 的 `EntityState.local_cell` 就是 footprint origin。Furniture 直接用 origin 加 Definition-local footprint Cell 计算占用 world Cell，并用同一 origin 加 UseSlot / SlotEntrance 的 `local_cell` 完成 Location Cell 转换。FurnitureRepresentation 自己从 footprint bounds 计算视觉中心；这个 Scene `Vector2` 不会写回 State。Physics collision 也只从同一份 `footprint_cells` 派生：每个 occupied local Cell 创建一个完整 `LocationGridSpace.CELL_SIZE × LocationGridSpace.CELL_SIZE` 的 RectangleShape2D，按 Cell 中心定位；不使用 bounding rectangle、不做 4px 内缩、不维护第二份 collision footprint 数据。non-blocking Furniture 保留对应 shape 但将其禁用。Location 不生成、删除或修改 Definition，只复用当前 Ground、Structure 与 Entity 查询验证可用性。UseSlot 位于目标 Entity footprint 内时会忽略目标自身的 blocking，但仍检查 Ground、Structure 和其他 blocking Entity；SlotEntrance 必须是普通 Actor 当前可站立的 Cell。Definition 是否存在与当前是否可用是两件事。

## Action 与 Interaction

PlayerController 把玩家输入转化为方向移动意图或交互意图。方向输入先立即写入普通 `ActorState.facing`，再尝试向 LogicalMovementRuntime 提交最新四向 direction intent；即使相邻 Cell 被墙、Furniture 或 Actor 阻挡，Actor 仍留在原 Cell，但 facing 已经改变并可用于 Interaction。PlayerController 不设置 velocity、不调用 `move_and_slide()`、不移动 ActorRepresentation，也不回写 ActorState 位置。它不创建 PlayerDefinition、PlayerState 或 Player 专属 occupancy，只向一个普通 Actor 提供当前玩家控制。

PlayerController 直接从当前 Location 查询 Entity，按 Actor 当前 Cell、facing、Action UseSlot 和当前 Runtime 有效性选择候选；有明确方向限制且当前 facing 被允许的 Slot 优先于 unrestricted Slot，完全同级时按稳定 instance UUID 排序。Representation、Scene 索引和物理节点都不是交互目标的逻辑来源。

WorldAction 使用逻辑 EntityState 验证同一 Location，然后由 ActionSpatialRule 要求 Actor 当前 Cell 匹配至少一个当前有效、朝向正确的 Action UseSlot。contracted 与 requesting Actor 仍稳定提交在 tail Cell，可以在满足 Slot 和 facing 时开始 Spatial Action；extended Actor 正在 Cell Transition，不稳定占据任何单一 Slot Cell，因此以 `actor_in_cell_transition` 正式拒绝。没有 Location 时直接 reject，不再使用仅检查 Slot/facing 的 fallback。旧的“目标位于脚下或面前”判断已删除；默认 UseSlot 保留相同体验，并成为唯一交互空间权威。Entity 默认拒绝 Action 并默认不阻挡移动；Furniture 把具体检查与执行委派给 Behavior，并按 FurnitureDefinition 提供统一的移动阻挡结果。合法结果修改 EntityState 或 GameTimeState；Representation 只刷新视觉。

## Logical Actor Movement

Movement 是 Logical World 能力。正式数据流为：

```text
PlayerController direction intent / NPC target intent
  ↓
LogicalMovementRuntime
  ├─ direction：指定邻格 + WAIT
  └─ target：AStarGrid2D 静态路线候选
  ↓
Causal-PIBT 当前一步协调
  ↓
tail / head / phase + elapsed / duration
  ↓
Step 完成时 ActorState.local_cell = head
  ↓
ActorRepresentation：Cell Center + progress 插值（存在时）
```

`LogicalMovementRuntime` 是独立于 Location Scene 的 Autoload。Player 与 NPC 都进入同一个 Request 集合。每个 `ActorMovementRequest` 保存 intent kind、目标或指定方向、original/current priority、contracted/requesting/extended phase、tail/head、parent/children、按优先顺序维护的候选集合 `C_i`、已搜索集合 `S_i`，以及一格 Step 的 `step_elapsed` 与 `step_duration`。`progress = elapsed / duration` 只表示 Step 完成比例，不是 Actor 的连续逻辑坐标。Location Scene 是否加载不影响 Request 推进；重新生成 ActorRepresentation 时，它直接从当前 tail/head/progress 恢复表现。

全局路线由 `AStarGrid2D` 直接消费 Location 的当前逻辑数据建立，只允许上下左右移动。Location bounds、Ground walkability、Ground movement cost、Structure 和 blocking Furniture / Entity 来自同一份 Location Definition + State 合并结果；Scene、TileMap、Physics Collision、NavigationAgent2D 或 NavMesh 都不是路线来源。动态 Actor 不写入静态 A* 墙，它们由 Causal-PIBT 处理。

NPC target intent 每次从当前 tail 取得可到达 target 的四向静态合法邻格，按 A* 剩余成本排序，并保证 A* 推荐 next Cell 优先，最后追加 WAIT；PIBT 临时改选后，下一次 contracted 从新 tail 重新取得 guidance。direction intent 的 `C_i` 只包含 Controller 指定邻格与 WAIT，因此协调不会把玩家自动改向其他邻格。

局部协调使用 Causal-PIBT 的核心三阶段：

- contracted：稳定占据 `{tail}`；
- requesting：请求 `tail → head`，逻辑占用仍为 `{tail}`；head 只是协调意图，不是 hard occupancy；
- extended：请求批准后推进 Step progress，严格占据 `{tail, head}`，直到整格位移完成才收缩为新 `{tail}`。

基础 priority 由 Movement Request 开始时间决定，同一 movement clock 使用 Actor instance UUID 稳定决胜；current priority 只在当前协调关系中临时继承，original priority 不被覆盖。正式 activation 直接维护 parent/children、`C_i` 与 `S_i`：高优先 requesting Actor 指向另一个 participant 的 tail 时，阻挡者建立 parent 关系、继承 current priority，并从父级 `S_i` 继续搜索；child 没有候选时把 `S_i` 传播回 parent，parent 回到 contracted 并尝试剩余 `C_i`。request cycle 通过“child head 是否已经位于 parent `S_i`”识别并回退。相同 head 的 requesting contenders 按 current priority 只批准一个。实现不再使用 `STATUS_VISITING`、递归 `_resolve_movement()`、assignments/head owners 或 snapshot/restore 模拟继承与回溯。

协调成功不会让整条依赖链同时进入 extended：只有 head 当前没有 hard occupancy 的依赖叶节点先开始移动，上游保持 requesting，直到下游真正完成并释放旧 tail 后才依次进入 extended。不同 Actor 速度不同时，整条链的 phase occupancy 仍不会重叠。Request 完成、取消或 Actor 离开原 Location 后会清理 participant 及其 parent/children 关系。

ActorState.local_cell 在 contracted(A)、requesting(A,B) 与整个 extended(A,B) 期间都保持 `A`；只有 `progress >= 1` 时才一次性 Commit 为 `B`。单格 `step_duration = LocationGridSpace.CELL_SIZE / ActorDefinition.move_speed`，不同 Actor 独立完成各自的 extended phase，不使用统一 movement timestep。LogicalMovement 不逐帧修改任何 State `Vector2`，也不从 Representation 或 pixel position 反推 Cell。

ActorRepresentation 负责 Cell → Pixel。contracted Actor 显示在 `LocationGridSpace.cell_to_center_position(local_cell)`；extended(A,B) 显示在 `lerp(cell_center(A), cell_center(B), progress)`。因此画面保持平滑连续，但 Logical World 始终只有 committed Cell 和 Movement Step。Scene 在 extended 中途销毁不影响 elapsed/duration；中途重建时 Representation 使用同一 progress 恢复当前位置，而不是从零重新播放。

非 participant Actor 使用自己的 `current_cell` 参与 hard occupancy。Player-controlled Actor 不再是 external movement control，而是与 NPC 一样成为普通 Causal-PIBT participant；差异只在于 direction intent 与 target intent 生成不同的 `C_i`。玩家在 extended 中改变方向时，当前单步继续完成，之后从新 tail 使用最新缓存方向；释放输入则完成当前单步后停止。Location Change 也先清除方向 intent，并等待已经开始的逻辑单步完成，避免半格 Transfer。

V11.2 只实现 Causal-PIBT 核心局部协调。当前只有已经持有 Movement Intent 的 Actor 会成为可继承 participant；没有 intent 的静止 Actor 是 hard obstacle，系统不会擅自替它生成移动目标。算法不提供 RHCR、SIPP、未来时间或 edge reservation、CBS / ECBS、完整 Joint MAPF、dead-end 特殊扩展、congestion guidance、traffic optimization、ORCA / RVO、Schedule、Goal 或 AI。在没有空闲节点或可行候选的拓扑中，Actor 仍可能合法 WAIT；本轮没有用特殊走廊、dead-end 或 retry 规则掩盖这一限制。

## 世界时间

GameTimeState 是独立于 Entity 与 Location Scene 的世界级事实，只保存 `total_minutes`。年月日、时分、星期与季节由统一日历规则推导。GameClock 负责帧率无关的推进与变化通知；HUD 只订阅并显示。

睡眠沿正式 Action 链推进到下一天 08:00。Furniture 不保存另一份时间，也不直接修改 UI。

## 暂不规定的事项

当前不实现 Location Editor、Dungeon / Town PCG、AI、Schedule、Goal、Behavior Tree、SIPP、未来时间 Reservation、Edge Reservation、CBS / ECBS、RHCR、ORCA / RVO、复杂 deadlock / congestion 扩展、Slot 占用预订、自动前往 SlotEntrance、从 Entrance 进入 UseSlot、坐下、躺下、动画、Ownership、Home / Workplace、复杂地图破坏或完整 Save / Load 重构。当前不为这些方向预建 Manager、Registry、状态或移动流程；出现真实消费者后再设计。
