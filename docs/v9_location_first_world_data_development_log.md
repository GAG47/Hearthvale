# V9：Location-First World Data 开发日志

日期：2026-08-16（2026-08-17 Project Definition Resource 化）

## 最终 Definition 规则

Definition 继续表示实例生命周期内稳定的规格，State 继续表示具体实例会变化的世界事实。Project Definition 的数据载体已经统一为 Godot Custom Resource：ActorDefinition、FurnitureDefinition、GroundTileDefinition、DecorationTileDefinition、StructureTileDefinition 与 LocationDefinition 都直接继承 Resource。

Project Definition 不再拥有业务 UUID，也没有公共 Definition 代码基类。Entity 和 Location Instance 继续使用独立 UUID v4 `instance_id`；EntityState 与 LocationState 不保存 Definition 身份。Actor、Furniture 和 LocationRuntime 直接持有对应的强类型 Definition Resource。

ActorDefinition 的四向视觉直接引用 Texture2D。FurnitureDefinition 直接引用 Texture2D，并以 SleepableBehavior、OpenableBehavior、InspectableBehavior Resource 保存稳定的能力配置；OpenableState 等运行变化仍属于具体 FurnitureState。

## Project Resource 数据

当前唯一 Project Definition 数据源是 `.tres`：

```text
data/actors/
├─ player.tres
└─ martha.tres

data/furniture/
├─ wooden_chest.tres
├─ sign.tres
└─ simple_bed.tres

data/tiles/
├─ ground/*.tres
├─ decoration/*.tres
└─ structure/*.tres

data/locations/
├─ tavern.tres
├─ town_street.tres
└─ tavern_yard.tres

data/world/project_world.tres
```

Actor、Furniture、Tile 与 Location 的旧 JSON 以及三个手写 Loader 已删除。Resource 之间直接保存 ExtResource 引用；业务代码不保存 Resource UID 字符串或资源路径字符串来手工查回 Definition。

`project_world.tres` 是现有 Project Location instance spec 的最小静态入口。每项只保存项目键、Location Instance UUID 与 LocationDefinition Resource，不承担 Definition 枚举、注册或生成职责。

## Location 世界数据

LocationDefinition Resource 完整保存 Topology 与 Spatial Layout：

```text
LocationDefinition
├─ outgoing_edges: Array[LocationEdgeDefinition]
├─ ground_layer: cell → GroundTileDefinition Resource
├─ decoration_layer: cell → DecorationTileDefinition Resource
├─ structure_layer: cell → StructureTileDefinition Resource
├─ entries: Array[LocationEntry]
└─ exits: Array[LocationExit]
```

LocationEdgeDefinition、LocationEntry 与 LocationExit 是 LocationDefinition 内部 Resource，不是新的 Definition。三个 Tile Layer 的 Cell 直接引用独立 TileDefinition `.tres`；连续墙体直接记录为多个 Cell，双格门洞由左右两个 StructureTileDefinition Resource 分别占据一格。

当前 Tavern、Town Street 与 Tavern Yard 共包含 1,608 个 Ground Cells、0 个 Decoration Cells、506 个 Structure Cells、5 个 LocationEntries 与 4 个 LocationExits。项目包含 9 个 GroundTileDefinition、0 个 DecorationTileDefinition 与 10 个 StructureTileDefinition Resource。

## Runtime 与 State

WorldDefinitionRuntime 直接加载 `project_world.tres`，建立 `Location instance_id → LocationDefinition Resource` 映射，并继续验证 Location Instance、完整 Ground、Cell 范围、Edge、Entry、Exit 和目标连接等真实业务约束。它不加载 Actor/Furniture Definition，也不执行 Definition 注册或 UUID 查找。

LocationRuntime 只组合 LocationDefinition Resource、LocationState 与 EntityRegistry。LocationState 的三层 sparse override 直接保存对应 TileDefinition Resource，`null` 表示当前 Cell 为空。LocationRuntime 统一合并 Definition Layer 与 State override，再向 SceneBuilder、通行规则和其他消费者提供当前结果。

Actor 和 Furniture 直接持有 Project Definition Resource；EntityState 只保存 `instance_id`、`current_location_id`、`local_position` 与具体运行状态。EntityRegistry 继续按 `instance_id` 管理实际 Entity Instance，但不再承担任何 Definition 解析职责。

## Scene 与切换

LocationSceneBuilder 继续从当前 Ground、Decoration、Structure、Entries、Exits 和 Entities 动态生成 GridScene。三个 TileMapLayer 共用固定 World TileSet；Entity 表现继续由 EntityRepresentationRegistry / Factory 创建。

Location 切换仍采用 Prepare → Commit。Prepare 解析目标 LocationRuntime、LocationEntry、静态层和 Entity Representations，并预检活动 Scene 注册；失败只释放临时树。Commit 才迁移 ActorState、激活目标 Scene、换绑 PlayerController 并释放旧 Scene。Scene 始终是 Resource Definition + Runtime State 的下游 Representation。

## 已删除链路

- Definition 公共代码基类；
- Definition UUID 与 EntityState / LocationState 中的 Definition ID；
- DefinitionRegistry Autoload 及其注册、查找、重复校验；
- ActorDefinitionLoader、FurnitureDefinitionLoader、ProjectWorldDataLoader；
- Actor、Furniture 和 Project World Definition JSON；
- JSON Dictionary 到 Definition 的转换与兼容路径。

没有新增 ResourceRegistry、DefinitionCatalog、UID 包装层、JSON fallback 或迁移 Adapter。EntityRegistry 与 EntityRepresentationRegistry 保持原职责。

## 明确未引入的路线

本轮没有恢复 Scene Authoring、Baking、Scene → World Data、Placement Baking 或 Location Baking。当前权威方向保持为：

```text
Project Definition Resources + Runtime State
  ↓
Runtime
  ↓
Scene Representation
```

## 验证

- Project Definition Resource 专项：2,230 项检查通过；
- ActorDefinition Resource：25 项检查通过；
- FurnitureDefinition Resource：24 项检查通过；
- V7.4.1 Entity 运行链：112 项检查通过；
- V7.5 Prepare → Commit：39 项检查通过；
- V8 Entity Representation System：41 项检查通过；
- EntityRegistry：24 项检查通过；
- Headless smoke 正常退出，无脚本、资源加载或 Autoload 错误。
