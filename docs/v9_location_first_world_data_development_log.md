# V9：Location-First World Data 开发日志

日期：2026-08-16（2026-08-17 V9.1 Spatial Layout 修正）

## 最终数据规则

V9 统一了长期世界对象的 Definition / State / Instance 概念。Definition 保存实例生命周期中稳定的规格；State 保存具体实例会变化的事实；Instance 同时拥有独立 UUID v4 `definition_id` 与 `instance_id`。ActorState、FurnitureState 与 LocationState 都显式链接 Definition UUID，EntityRegistry 会验证 Runtime Entity、State 与 DefinitionRegistry 对象一致。

DefinitionRegistry 统一登记当前项目中的 Actor、Furniture、GroundTile、DecorationTile、StructureTile 与 Location Definition。Registry 只服务已有 Project Definitions，不提供运行时生成、序列化或恢复路径。

## Location 世界数据

LocationDefinition 不依赖固定 Scene，最终组成是 Topology 与直接的 Spatial Layout：

```text
LocationDefinition
├─ Topology
│  └─ outgoing_edges
└─ Spatial Layout
   ├─ ground_layer: cell → GroundTileDefinition UUID
   ├─ decoration_layer: cell → DecorationTileDefinition UUID
   ├─ structure_layer: cell → StructureTileDefinition UUID
   ├─ entries
   └─ exits
```

GroundTileDefinition 保存通行规则与移动成本；StructureTileDefinition 保存逻辑阻挡；三种 Tile Definition 都只保存固定 World TileSet 中的 `source_id`、`atlas_coords` 和 `alternative_tile`。它们不指定 TileSet，也不通过泛型数据决定表现类型。

三层空间数据都直接记录每个 Cell 使用的 Tile Definition。连续墙体是多个 Structure Cell；双格门洞拆分成左右两个 Tile Definition，各自占据一格。静态 Tile 不拥有独立实例身份。Door、Chest、Bed、Workbench、Actor 等有独立身份、State 或交互的对象仍属于 Entity，位置权威仍是 `EntityState.current_location_id` 与 `EntityState.local_position`。

Topology 的边保存 edge UUID、局部 edge key、目标 Location Instance UUID 与目标 Entry ID。LocationEntry 直接保存 Entry ID、Cell 与 Facing；LocationExit 直接保存对应 Edge Key 与本地 Cell Rect。两者只表达连接在当前 Location 中的空间位置，Topology 继续负责连接目标。

## Sparse LocationState 与 LocationRuntime

LocationState 的三层空间变化与 Definition 使用相同 Cell 模型：

- `ground_overrides`；
- `decoration_overrides`；
- `structure_overrides`。

每项是 `cell → TileDefinition UUID`，空 `StringName` 表示当前 Cell 被移除。未变化的地点 State 不复制完整空间层；Topology 仍使用 removed、disabled 与 added edge sparse overrides。LocationRuntime 统一合并 Definition 与 State，提供当前三层 Cell Layer、Entries、Exits、Topology、通行性与 Entity 查询，其他消费者不重复解释覆盖语义。

## Location → Scene

LocationSceneBuilder 按 Ground → Decoration → Structure 生成三个直接的 TileMapLayer，三层共用固定 World TileSet。它再从 Entries 建立 Marker2D，从 Exits 建立 LocationExitArea，并通过既有 EntityRepresentationRegistry / Factory 为当前 Entities 准备表现。构建流程没有基于字符串的表现分派，也不会为地点名称创建 Decoration Node。

当前 Tavern、Town Street 与 Tavern Yard 的项目数据位于 `data/world/project_world.json`：共 1,608 个 Ground Cells、0 个 Decoration Cells、506 个 Structure Cells、5 个 LocationEntries 与 4 个 LocationExits。项目 Registry 包含 9 个 GroundTileDefinition、0 个 DecorationTileDefinition、10 个 StructureTileDefinition，以及既有 Actor、Furniture 和 Location Definition。三份固定地图 `.tscn` 已删除，Scene 始终是 Location 世界数据的下游 Representation。

Location 切换继续使用 Prepare → Commit。Prepare 解析目标 LocationRuntime、LocationEntry、全部静态层和 Entity Representations，并预检活动 Scene 注册；任一步失败都只释放临时树。Commit 才迁移 ActorState、激活目标 Scene、换绑 PlayerController 并释放旧 Scene。离开后 LocationDefinition、LocationState、Entity、EntityState 与 BehaviorState 都继续存在，返回时从当前数据重新生成 Scene。

## V9.1 边界修正

- 三种 Spatial Definition 收束为明确的 Tile Definition，并使用显式 Tile 字段。
- 三层 Location Spatial Layout 统一为直接 Cell Layer。
- 静态结构与装饰不再拥有额外实例身份、方向或 footprint 展开过程。
- Entry 与 Exit 成为直接数据，不再共享没有消费者的中间基类。
- 原地点文字从 Decoration Layer 删除，当前 Decoration Layer 保持为空。
- LocationState 使用三层 Cell override，空 ID 统一表示当前 Cell 为空。
- LocationSceneBuilder 只消费 LocationRuntime 的最终 Cell Layer、Entries、Exits 与当前 Entities。
- Entity Definition、State、Runtime 与 Representation 边界保持不变。

## 明确未引入的路线

V9.1 没有实现 Location Editor 或 PCG，也没有建立 Scene → Authoring → Baking → World Data。工程中没有 fingerprint、bake cache、preflight 或 Location Baking。PCG 将在真正开始设计和实现时重新建立数据、Registry 与持久化边界，当前版本不为其预设接口或兼容层。

## 验证

V9.1 专项覆盖 Project Definition 解析、三层直接 Cell 数据、LocationState sparse Cell override、空 Cell override、固定 TileSet Scene 构建、Entry / Exit、Scene 卸载后的世界数据持续与往返重建。回归验证同时覆盖 Location Prepare → Commit、Actor Move、Interaction、Entity Representation、Actor / Furniture Definition Loader、EntityRegistry 与 Headless 启动。

- V9.1 Location Spatial Layout 专项：2,302 项检查通过；
- V7.4.1 Entity 运行链：113 项检查通过；
- V7.5 Prepare → Commit：39 项检查通过；
- V8 Entity Representation System：41 项检查通过；
- ActorDefinitionLoader：53 项检查通过；
- FurnitureDefinitionLoader：22 项检查通过；
- EntityRegistry：22 项检查通过；
- Headless smoke 正常退出，无脚本或运行时错误。
