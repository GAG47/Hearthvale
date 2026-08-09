# V3 运行时 World State 开发日志

日期：2026-08-10

## 目标与边界

本次建立独立于 Godot Location Scene 生命周期的运行时世界事实层，证明一个动态事实在承载它的 Scene Node 被释放后仍属于当前世界。

本次没有实现磁盘 Save / Load、JSON、存档槽、存档迁移、CharacterState、Location 动态状态、事件状态、NPC 或离屏模拟。

## 运行时 WorldState

`scripts/world_state/world_state.gd` 作为项目唯一的 WorldState Autoload，在整个游戏运行周期内持续存在。当前公开的通用状态能力是：

- `get_object_state(object_id) -> WorldObjectState`；
- `register_object_state(object_id, state) -> bool`；
- `has_object_state(object_id) -> bool`。

WorldState 没有 `get_chest_state()`、`get_or_create_chest_state()` 或其他业务对象专用接口。它只保存和查询通用 WorldObjectState，不创建、不解释具体 State。

WorldState 的事实表以稳定逻辑 ID 为键，在 Location Scene 卸载后继续持有状态。场景路径不用于查询或引用世界事实；仅保留为重复 `location_id` 的开发期来源诊断。

内部数据分成两个明确区域：

- `_object_states` 是真正的动态世界事实；
- 固定对象 Definition 记录、当前活动 Location、当前活动 WorldObject 和 Location 场景来源是运行时登记及开发期诊断，不是世界事实。

## Location 稳定身份

GridScene 增加稳定 `location_id`：

| Location | location_id |
| --- | --- |
| 酒馆 | `tavern` |
| 小镇街道 | `town_street` |
| 酒馆后院 | `tavern_yard` |

Location 进入 SceneTree 时向 WorldState 登记逻辑身份，离开时注销当前活动实例。现有 `.tscn` 路径仍只服务 Game 的场景加载，不替代 `location_id`。

增加新的手工 Location 时，只需让新的 GridScene 自己声明一个未使用的 `location_id`；当前没有中央 Location Registry 或需要同步的 ID 列表。

## 纯粹的对象身份

当前三个固定 WorldObject 的人工 ID 是：

| 对象 | object_id |
| --- | --- |
| Chest | `obj_000001` |
| Sign | `obj_000002` |
| Bed | `obj_000003` |

这些 ID 只回答“这是哪个具体实体”，不编码 Tavern、对象类型、用途或状态。同一实体以后移动时 ID 不变；实体真正删除后旧 ID 不代表新实体。当前没有运行时创建或删除对象的需求，因此没有自动 ID Generator。

## Definition 与 State

Chest Scene 继续定义 `object_id`、初始 Location、格子位置、占位、碰撞、初始 CLOSED 和静态贴图等内容。WorldState 不复制 SceneTree、TileMap、Sprite 或碰撞数据。

WorldObjectState 是抽象的具体状态类型基础，目前只存在 ChestState。ChestState 只保存一个实际动态事实：

```text
status = CLOSED | OPEN
```

WorldState 的字典键负责关联 `object_id`。固定场景实例通过独立 `initial_location_id` 声明 Definition 的初始地点，Definition 登记记录该值和对象类型以发现场景配置冲突；ChestState 本身没有万能 Dictionary、语义标签或无消费者字段。初始 Location 不属于 ID 的含义，也不是未来对象当前位置的永久约束。

当前固定对象的位置属于 Definition。未来可移动对象的 `current_location`、`current_cell` 和 orientation 应进入其具体动态 State；移动不会改变 `object_id`。本次没有实现 Furniture、家具移动或布置系统。

Sign 的文字是静态定义，Bed 的 sleep 当前只产生规则失败，两者没有跨 Scene 变化，因此不创建 SignState、BedState 或空状态记录。三个 Location 也没有动态事实，不创建 TavernState 等对称空结构。

## Chest 状态绑定与 Action

Chest Node 完成稳定身份登记后，通过 `obj_000001` 使用 WorldState 的通用接口：

1. 调用 `get_object_state(object_id)`；
2. 没有状态时由 Chest 按 Definition 的初始 CLOSED 创建 ChestState；
3. Chest 调用 `register_object_state(object_id, state)` 登记新状态；
4. 已有状态时由 Chest 校验它确实是 ChestState，然后直接绑定；
5. `open` / `close` 规则、执行和 Sprite2D 都读取同一 ChestState。

Chest Node 没有另一份独立的长期 closed/open 真相。它只持有权威 ChestState 的运行时引用。节点注销只移除活动实例和 Location 格子索引，不删除 WorldState 中的 ChestState。

## 稳定 ID 冲突

WorldState 对以下情况给出明确开发期错误并拒绝登记：

- 两个同时加载的 Location 使用相同 `location_id`；
- 两个同时加载的 WorldObject 使用相同 `object_id`；
- 已知固定 `object_id` 的初始 Location 或对象类型与已有 Definition 记录冲突；
- Location 或 WorldObject 缺少非空稳定 ID。

相同场景重载后的新 Node 可以使用同一个逻辑 ID，并重新绑定已有世界事实。

## 实际验证

使用 Godot 4.7.1 完成以下运行验证：

- 初次进入酒馆时 ChestState 为 CLOSED，Chest 使用关闭贴图；
- 玩家执行 open 后 Action 成功、ChestState 为 OPEN、视觉变为打开；
- 进入小镇街道后，旧 Tavern 与 Chest Node 均确认已释放，ChestState 在无 Tavern Node 时仍为 OPEN；
- 返回酒馆后创建了新的 Tavern / Chest Node，新 Chest 以相同 `object_id` 绑定同一个 ChestState，并直接显示 OPEN；
- 执行 close 后 ChestState 变为 CLOSED；
- 再次进入后院并返回酒馆，新 Chest Node 仍显示 CLOSED；
- Sign inspect、Bed sleep 失败反馈保持正常，且 WorldState 中没有对应空状态；
- 越过 Selector 创建的超出交互格或跨 Location Action 仍由 ActionSpatialRule 拒绝，ChestState 不发生变化；
- Chest、Sign、Bed 碰撞、四方向连续移动、禁止对角移动和四个实际出口切换均正常；
- 重复 Location ID、重复活动 Object ID，以及同 ID 的初始 Location / 对象类型 Definition 冲突均输出明确错误，没有静默共享状态。

## 当前限制

WorldState 当前只服务一次游戏运行，退出进程后状态不会保留。PlayerCharacter 仍通过自身跨 Location 的现有生命周期保存当前运行信息，没有额外 CharacterState。当前也没有自动 ID 生成、动态对象创建/删除、家具移动、Furniture 抽象或磁盘 Save / Load。未来磁盘存档应序列化 WorldState，但具体格式和加载流程尚未设计。
