# V10：Location Logical Space / Scene Management

日期：2026-08-16

## 本次目标

V10 在现有 WorldDefinition、Entity、EntityState、Placement Baking 与 Representation 生命周期之上建立独立 Location Logical Space。完成后，Location 的静态空间、Entity 占格、Action Use Slot 与空间查询不再以某个已加载 Scene、Physics 或 Representation 为存在条件。

本文同时记录基于首个 V10 实现 `ffb9fde` 完成的定点修正：收紧 Runtime / Authoring 边界、明确逻辑 TileMapLayer、修正 Use Slot 推导并补齐自动 Preflight；这些改动仍属于 V10，不建立新的子版本，也不改变既定核心结构。

Location 的正式逻辑组成固定为：

```text
Location
├─ Static Grid
├─ Entry / Exit
└─ Entities
```

Spatial Index 是由 EntityState 与 Definition 派生的运行时查询缓存；Decoration 只属于 Scene。两者都不成为 Location 的第四种持久组成。

## Static Grid 与 LogicalLocationData

现有 Location `.tscn` 和 TileSet 继续作为制作源。`world_tileset.tres` 新增 `walkable` 与 `movement_cost` Custom Data Layer，所有参与逻辑空间的 Tile 明确给出两项数据。普通地面、草地、道路和门槛当前可走，墙、固定结构、围栏、建筑与静态障碍不可走，第一版移动成本统一为 1。

`LogicalLocationCompiler` 只 headless 编译明确标记 `participates_in_static_grid = true` 的 TileMapLayer。视觉与装饰层默认不参与，不要求拥有逻辑 Custom Data，也不会改变 bounds、walkability 或烘焙成功与否。当前 Ground 与 Structures 都明确参与同一个 32 × 32、无旋转缩放且按 Cell 对齐的逻辑坐标系；明显不兼容的参与层会被拒绝。多个参与层重叠时任一层 blocked 即使该 Cell blocked；所有实际参与 Tile 的最小包围 Rect 成为 bounds，bounds 外和 bounds 内没有 Logical Tile 的孔洞默认 blocked。输出 `LogicalLocationData` 使用 bounds 映射到连续 `PackedByteArray` / `PackedInt32Array`，支持 O(1) walkability 与 movement-cost 查询，不为每个 Cell 建立 Node 或 Resource。

烘焙产物还保存 Entry / Exit、source fingerprint 和 compiler version；本次逻辑层选择规则变化后 compiler version 更新为 2。Entry 包含稳定 `entry_id`、Cell、Location-local position 与 facing；边仍只引用目标 Location 的 `entry_id`，Entry 不复制来源连接。产物不保存 Entity、State、Spatial Index、Use Slot 实际位置、Navigation、Reservation、Representation 或 Scene Node。

当前正式产物是：

- `data/locations/tavern.tres`：24 × 16；
- `data/locations/tavern_yard.tres`：24 × 18；
- `data/locations/town_street.tres`：36 × 22。

## Location Bake Preflight

`tools/bake_logical_locations.gd` 从 WorldDefinition 枚举正式 Location。source fingerprint 覆盖每个 Location Scene 文件及其外部 TileSet 文件，因而包含影响结果的 TileSet Custom Data；compiler version 处理编译规则或格式变化。

Preflight 对每个 Location 独立判断：未变化时跳过，缺失、指纹变化、版本变化或数据形状错误时只重烘焙对应产物。编译或保存失败会返回非零退出码，因此不会静默继续使用旧 Static Grid。source fingerprint 的计算和 stale 判断只属于 Bake / Preflight；运行时 LocationSpace 不打开 `.tscn`、TileSet，也不重新计算指纹。

启用的 `Location Bake Preflight` EditorPlugin 通过 Godot `_build()` 钩子在编辑器启动游戏前自动调用同一 Compiler；失败会返回 `false` 并阻止运行。`tools/run_tests.sh` 与 `tools/build.sh` 在执行正常测试或 Godot 构建参数前也会自动运行同一 headless Preflight，并通过 shell fail-fast 直接传播失败，不需要开发者另外记住烘焙命令。

直接维护烘焙产物的命令：

```bash
godot --headless --path . --script res://tools/bake_logical_locations.gd
```

标准 CLI 测试与构建入口：

```bash
tools/run_tests.sh
tools/build.sh <Godot build/export arguments>
```

Location Bake 与 V9 Placement Bake 保持独立：前者生成静态 LogicalLocationData，后者继续生成 Initial Entity Data，没有改写 Placement → EntityFactory → Entity + EntityState 链路。

## Runtime Logical Location 与 Spatial Index

新增 `LocationSpace` Autoload，在 Scene 生命周期之外只加载三个 LogicalLocationData，并校验资源存在、location_id、compiler version 与烘焙数据结构，再为每个地点建立 `LogicalLocation`。运行时不会读取 Location Scene、TileSet 或 source fingerprint。它提供正式查询：

- bounds、Static Walkability 与 movement cost；
- Static Grid + blocking Entity Occupancy 的 Current Walkability；
- Cell 中的 Entity、Entity 当前 occupied cells、Location 中的 Entities；
- 支持某 Action 的 Entities；
- Entity 某 Action 的 Use Slots 与当前有效 Slots。

EntityRegistry 提交 Entity 后通知 LocationSpace 建立索引。`cell → entity IDs` 与反向 occupied-cell 缓存可以完全由 EntityRegistry、EntityState 与 Definition 重建；Scene 加载/卸载不注册或删除逻辑占格。Furniture 多格 footprint 继续兼容 V9.2 的矩形 `occupied_cells`，统一展开为相对 footprint offsets，床的两个实际 Cell 都进入索引。

`EntityState.local_position` 仍是唯一持久位置真相，`current_cell` 不另行保存。LocationSpace 的统一移动边界先验证目标 Location、Static Grid 与当前 blocking occupancy，再 Commit `current_location_id` / `local_position`，最后同步旧、新 Spatial Index。ActorRepresentation、FurnitureRepresentation 与 Location 切换都改走该边界，不再散落直接位置写入。

## Use Slot 与 Action 空间规则

新增 `UseSlotDefinition`，表达 `relative_cell`、`required_facing` 和 `supported_actions`；坐标原点是 Entity footprint 左上角。显式配置通过 Entity 的最小空间能力接口查询，不在 LogicalLocation 中硬编码 Furniture 类型；当前 FurnitureDefinition 继续承载实际数据。显式/默认选择按 Action 独立判断：床的 sleep 使用左侧上格显式 Slot，而同一 Entity 没有显式配置的其他 Action 仍生成默认 Slot。默认 Slot 包含 footprint 外沿；非 blocking 的可交互 Entity 还为 occupied Cell 生成各 facing 的脚下 Slot，因而同时保留“脚下 + 面前”交互，blocking Entity 不会在自身 footprint 生成默认 Slot。最终统一过滤越界、静态 blocked 或被其他 blocking Entity 占据的位置。

InteractionTargetSelector 不再查询 FurnitureRepresentation 或 GridScene 局部索引。它从 Actor 当前 Logical Location 查询支持行为的 Entity，并选择 Actor 已经满足的有效 Use Slot。WorldAction 的公共空间规则再次验证同 Location、Slot Cell 与 required facing；离屏或测试调用可以显式携带 LogicalLocation，规则不要求 SceneTree 中存在目标 Scene。

## Scene / Representation 生命周期

进入 Location 时，Logical Location 与 Spatial Index 已经存在。Prepare 根据逻辑 Entry、目标 Entities 与当前 EntityState 创建目标 Scene 和 Representations；Commit 通过 LocationSpace 移动 Actor、应用 Entry facing、更新索引并换绑 PlayerController。退出后 Scene 与 Representation 被销毁，但 Logical Location、Entity、EntityState、Occupancy、Spatial Index 和 Use Slot 查询继续存在。

WorldDefinition 启动时不再为了验证世界图实例化全部 Location Scene。LocationSpace 使用烘焙 Entry / Exit 验证图连接，实际 GridScene 只在需要显示时加载。GridScene 原 FurnitureRepresentation 格子索引及登记代码已经删除。

## 数据权威

- WorldDefinition / Location Graph：Location 身份、Scene 映射与有向连接；
- LogicalLocationData：由 Scene + TileSet 编译的静态网格和 Entry / Exit；
- EntityState：Entity 当前 Location 与 Location-local position；
- Definition：Entity footprint、blocking、行为配置和 Use Slot 静态配置；
- LogicalLocation Spatial Index：从 State + Definition + EntityRegistry 派生，可随时重建；
- Scene / Representation：当前加载地点的临时视觉、物理碰撞、输入承载和出口触发，不是空间规则权威。

## 明确留给后续版本

V10 没有实现 NPC AI、Schedule、Goal、Memory、Relationship、寻路、离屏移动、Reservation、多 Actor 避让、Slot Entrance、坐下/躺下 Transition、Ownership 或床位/工作地点分配。Use Slot 当前就是 Action 执行位置，不被改写为未来 Navigation 的“接近位置”。

## 验证

- Location Bake 首次生成三个产物成功，再次 Preflight 三个均按指纹跳过；
- V10 专项 71 项检查通过，覆盖运行时不读取制作源、显式逻辑层与视觉层排除、参与层坐标约束与 blocked 优先合并、headless 编译、bounds / holes / costs、指纹和 compiler version、Entry / Exit、未加载 Scene 的静态查询、床的两格 Occupancy、`cell → entity`、Current Walkability、Action 级显式/默认 Use Slot、非 Furniture 显式 Slot 能力、脚下与面前交互、CLI 测试/构建 Preflight、统一移动与索引更新、Entry facing、Representation 恢复以及 Scene 卸载后的离屏查询；
- V7.4 / V7.4.1、V7.5、V8、V9、V9.1、V9.2 和基础 EntityRegistry 回归继续通过；V7.5 的“保留旧 facing”断言按 V10 正式 Entry facing 语义更新；
- 主场景 Godot 4.7.1 headless smoke 无错误；
- 逻辑查询实现不读取 CollisionShape2D、Area2D、Scene Physics 或 Representation。
