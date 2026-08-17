# V10：Entity Interaction Space 开发日志

日期：2026-08-18

## 目标与边界

V10 用正式 Entity interaction space 替换 ActionSpatialRule 中“Actor 脚下或面前是否包含目标 occupied Cell”的临时空间规则。本轮只实现 UseSlot、SlotEntrance 及现有交互迁移，没有引入 NPC、AI、Schedule、Navigation、Pathfinding、Reservation、自动移动、特殊 Slot Transition、坐下、躺下或动画。

世界数据权威关系保持不变：

```text
Project Definition Resource
  ↓
Runtime State
  ↓
Logical Runtime
  ↓
Scene Representation
```

没有增加 Definition 公共基类、DefinitionRegistry、Catalog、UID 包装、JSON Loader 或新的 World Data Layer。

## Definition 数据结构

UseSlot 与 SlotEntrance 都是 Godot Custom Resource，作为 ActorDefinition 或 FurnitureDefinition 的内部强类型数据：

```text
Entity Definition
├─ footprint_cells: Array[Vector2i]
└─ use_slots: Array[UseSlot]
   ├─ local_cell: Vector2i
   ├─ required_facing: ActorState.Facing
   ├─ supported_actions: Array[StringName]
   └─ slot_entrances: Array[SlotEntrance]
      └─ local_cell: Vector2i
```

Furniture 的 footprint 是 Definition-local Cell 集合，唯一权威字段为 `footprint_cells`。它可以表达不规则形状，例如 `[(0,0), (1,0), (0,1)]`；本轮不实现 rotation。

两类局部坐标都以 Entity footprint 左上角为 `(0, 0)`。UseSlot 可以位于 footprint 内外；SlotEntrance 属于一个具体 UseSlot。EntityState 继续只保存实例位置和其他运行事实，Entity 移动不会修改 Definition 中任何 Slot 坐标。

`ActorState.Facing.NONE` 表示 Slot 不限制朝向，仅用于 non-blocking Entity 的默认脚下 Slot。SlotEntrance 当前没有 facing 字段，因为本轮没有真实消费者需要 Entrance facing。

## 显式与默认 UseSlot

查询 `Entity + action_id` 时，先筛选 Definition 中 `supported_actions` 包含该 Action 的显式 UseSlot。只要存在匹配项，就完整返回显式项，不再为该 Action 生成默认 Slot。

如果没有任何匹配的显式 UseSlot，则直接从 Entity 的 Definition-local footprint Cells 派生临时默认结果：

- 对每个 footprint Cell 检查上、下、左、右；
- 只保留 footprint 外的相邻 Cell；
- 相同 local Cell 去重；
- 不生成对角 Slot；
- 左侧 Slot 要求 RIGHT，右侧要求 LEFT，上侧要求 DOWN，下侧要求 UP；
- non-blocking Entity 还为每个 footprint Cell 生成 `Facing.NONE` 的脚下 Slot；
- blocking Entity 不生成脚下默认 Slot。

默认结果不写回 `use_slots`，不会把运行查询变成 Project Definition 变更。

## SlotEntrance 规则

UseSlot 配置一个或多个显式 SlotEntrance 时，查询完整保留全部显式项，不自动选择唯一 Entrance。如果 `slot_entrances` 为空，则返回一个默认 SlotEntrance，其 `local_cell` 与 UseSlot 完全相同。

系统不从 footprint 生成周围一圈 Entrance，也不根据 UseSlot required facing 猜测 Entrance。SlotEntrance 本轮只提供 Definition 和 Runtime Query，不控制移动。

## Runtime 查询与校验

Furniture Runtime 直接把 Definition-local footprint Cells 平移到当前 Entity footprint origin；坐标转换统一为：

```text
world_use_slot_cell = entity_footprint_origin_cell + use_slot.local_cell
world_entrance_cell = entity_footprint_origin_cell + slot_entrance.local_cell
```

LocationRuntime 提供 Action UseSlot、SlotEntrance、world Cell、当前有效 UseSlot 与当前有效 Entrance 查询。它直接复用现有 Location Ground、Structure 与 EntityRegistry 空间事实，不复制 LocationSpace 数据。

UseSlot 当前有效需要：Entity 属于该 Location、world Cell 在 bounds 内、Ground 可站立、Structure 不阻挡、没有其他 blocking Entity。Slot 位于目标自身 occupied Cell 时忽略目标自身 blocking，使显式内部 Slot 与 non-blocking 脚下 Slot 能够正确验证，但不会忽略其他 Entity。

SlotEntrance 当前有效需要：Entity 属于该 Location、world Cell 在 bounds 内，并且该 Cell 是普通 Actor 当前可站立的位置。墙或 blocking Entity 只会令运行时查询返回不可用，不会删除或修改 SlotEntrance Definition。

## 交互迁移

InteractionTargetSelector 已删除。PlayerController 遍历当前 Location 的逻辑 Entities，根据 Actor 当前 Cell、facing、候选 Action UseSlot 和当前 Runtime 有效性选择 Entity + Action；同一位置的明确 facing 匹配优先于 `Facing.NONE`，完全同级时继续按稳定 instance UUID 排序。PlayerController 只负责玩家选择，ActionSpatialRule 仍是 WorldAction 的最终空间权威。

ActionSpatialRule 保留 Actor、Target、Location 身份检查，空间部分改为：

```text
Actor current Cell + facing
  ↓
Target Entity + action_id 的 UseSlot
  ↓
world Cell、required facing 与 LocationRuntime 有效性匹配
  ↓
允许或拒绝 WorldAction
```

旧的脚下 / 面前目标 Cell 判断已经删除。没有 V10 配置的普通 blocking Furniture 通过默认外部 Slot 保持面对交互；non-blocking Entity 通过默认 footprint Slot 保持脚下交互。ActionSpatialRule 在无法取得 LocationRuntime 时直接 reject，生产代码不保留测试 fallback。

## Scene 边界

UseSlot 与 SlotEntrance 不存入 GridScene 或 Entity Representation。Location Scene 销毁与重建后，查询仍由同一个 Definition Resource、EntityState 和 LocationRuntime 重新得到相同结果。V10 没有增加 Scene Authoring、Baking 或表现节点空间索引。

## 验证

V10 专项覆盖：

- 1x1 blocking Furniture 的四个非对角默认 Slot；
- 2x2 blocking Furniture 的八个去重外沿 Slot；
- L 型 Furniture 的 local footprint、occupied world Cells 和真实外沿默认 Slot；
- non-blocking Entity 的脚下与外部 Slot；
- 显式 Action Slot 排除默认 Slot；
- required facing 通过与拒绝；
- 默认 Entrance 等于 UseSlot；
- 多显式 SlotEntrance 与 world Cell 转换；
- EntityState 移动只改变 world Cell；
- Structure 和其他 blocking Entity 令 Entrance 当前不可用但不修改 Definition；
- 目标自身 blocking 不会错误否定内部 UseSlot；
- 现有 Furniture 面前交互和 non-blocking 脚下交互；
- facing Slot 优先于 `Facing.NONE`；
- 缺失 LocationRuntime 时 ActionSpatialRule reject；
- Location Scene 销毁重建后的 Slot / Entrance 一致性。

完整测试结果记录在本轮最终验证中。
