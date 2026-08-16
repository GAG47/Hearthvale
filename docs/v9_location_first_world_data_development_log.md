# V9：Location-First World Data 开发日志

日期：2026-08-16

## 最终数据规则

V9 统一了长期世界对象的 Definition / State / Instance 概念。Definition 保存实例生命周期中稳定的规格；State 保存具体实例会变化的事实；Instance 同时拥有独立 UUID v4 `definition_id` 与 `instance_id`。ActorDefinition 不再把 Entity 实例 ID 当作规格 ID，Furniture 的旧字符串 Definition ID 也已迁移为 UUID。ActorState、FurnitureState 与 LocationState 都显式链接 Definition UUID，EntityRegistry 会验证 Runtime Entity、State 与 DefinitionRegistry 对象一致。

DefinitionRegistry 现在统一登记 Actor、Furniture、Ground、Decoration、Structure 与 Location Definition。Project Definition 和 Generated Definition 共用同一 UUID 命名空间与查询入口。Generated Definition 可以序列化完整 Definition 数据并恢复；未来 PCG 应直接生成 LocationDefinition，注册后再创建 LocationState。正式恢复依赖保存的 Generated Definition 本身，不依赖重新运行 seed。

## Location 世界数据

LocationDefinition 已去除 `scene_path`，正式组成是 Topology、Spatial Layout 与 Anchors：

```text
LocationDefinition
├─ Topology / outgoing edges
├─ Ground Layer: cell → GroundDefinition UUID
├─ Decoration Placements
├─ Structure Placements
└─ Anchors
   ├─ Entry
   └─ 当前切换消费者需要的 Exit trigger
```

GroundDefinition 集中保存 walkability、movement cost 与 Tile 表现规格。DecorationDefinition 表达没有独立世界身份的装饰；当前地点文字也从 DecorationPlacement 生成。StructureDefinition 保存逻辑阻挡、逐 Cell footprint 和表现规格；StructurePlacement 保存 placement UUID、Definition UUID、origin cell 与 orientation。酒馆的上下门洞已迁移为真正的双格 StructureDefinition，运行时通过 `origin_cell + transformed occupied_cells` 得到实际占用。

Topology 的边保存 edge UUID、局部 edge key、目标 Location Instance UUID 与目标 Entry ID，不重复保存反向信息或目标 Entry 坐标。Entry Anchor 保存局部 Cell、Facing 和精确表现偏移。Location 当前 Entities 不进入 LocationState；LocationRuntime 始终通过 EntityRegistry 按 `EntityState.current_location_id` 查询，并按 Entity footprint 派生 Cell 查询。

## Sparse LocationState 与 LocationRuntime

LocationState 只保存相对 Definition 的变化：

- Ground overrides；
- removed / added Structures；
- removed / added Decorations；
- removed、disabled / added Topology edges。

未变化的地点 State 不复制任何完整空间层。LocationRuntime 负责合并 LocationDefinition 与 sparse overrides，并统一提供当前 Ground、可通行性、Structures、Entries、Topology、Entities 与 Cell Entities 查询。WorldState 持久持有三个 Project LocationState；活动 GridScene 仍只是弱引用的运行时表现登记。

## Location → Scene

LocationSceneBuilder 已成为 Location 到 Godot Scene 的通用桥梁。它按 Ground → Decoration → Structure → Anchors 建立静态层，并通过既有 EntityRepresentationRegistry / Factory 为当前 Entities 准备表现。Game 不加载 Location PackedScene，也不按 Actor / Furniture 类型创建表现。

当前 Tavern、Town Street 与 Tavern Yard 的世界事实已经迁移到 `data/world/project_world.json`：共 1,608 个 Ground Cells、502 个 Structure Placements（展开为 506 个 footprint Cells）、5 个 Decoration Placements、5 个 Entry Anchors 与 4 个 Exit Anchors。三份固定地图 `.tscn` 已删除。生成的 Scene Root 包含 GroundLayer、DecorationLayer、StructureLayer、EntryPoints、Exit triggers 与 EntityRepresentationRoot，保持原有碰撞、地点切换和交互能力。

Location 切换继续使用 Prepare → Commit。Prepare 解析目标 LocationRuntime、Entry、全部静态表现和 Entity Representations，并预检活动 Scene 注册；任一步失败都只释放临时树。Commit 才修改迁移 ActorState，激活目标 Scene、换绑 PlayerController 并释放旧 Scene。离开后 LocationDefinition、LocationState、Entity、EntityState 与 BehaviorState 都继续存在，返回时从当前数据重新生成 Scene。

## Project / Generated 统一路径

固定 Tavern 的运行路径是：

```text
Project TavernDefinition + TavernState → LocationRuntime → LocationSceneBuilder
```

专项测试建立的 Generated Location 使用完全相同的后半段：

```text
Generated LocationDefinition
  → DefinitionRegistry
  → LocationState
  → LocationRuntime
  → LocationSceneBuilder
```

查询、静态表现和 Entity 表现都不检查 Definition 来源。区别只存在于 Definition 的生产、首次注册和 World Save 持久化阶段。

## 明确未引入的路线

V9 没有实现 Location Editor 或真正 PCG，也没有建立 Scene → Authoring → Baking → World Data。工程中没有 fingerprint、bake cache、preflight、Scene Placement Baking 或 Location Baking。Scene 始终是 Location 世界数据的下游 Representation。

## 验证

- V9 Location-First World Data 专项：1,728 项检查通过；
- V7.4.1 Entity 运行链：113 项检查通过；
- V7.5 Prepare → Commit：39 项检查通过；
- V8 Entity Representation System：41 项检查通过；
- ActorDefinitionLoader：53 项检查通过；
- FurnitureDefinitionLoader：22 项检查通过；
- EntityRegistry：22 项检查通过；
- Headless 启动保持运行，无脚本或运行时错误。

专项覆盖 Definition / Instance UUID 分离、Project / Generated 统一解析与序列化、三层静态内容和 Anchors、LocationState sparse override、双格 Structure footprint 与旋转、Entity 派生查询、动态 Scene 构建、Scene 卸载后的世界数据持续、往返重建、现有移动、交互、Factory 与 Prepare 失败安全边界。
