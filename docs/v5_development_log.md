# V5 World Definition 与 Location Graph 开发日志

日期：2026-08-10

## 目标与边界

本次建立全世界统一的 Location 静态目录与有向空间图，使游戏不依赖当前加载的 Location Scene，也能查询世界中有哪些地点、地点对应哪个场景，以及从一个地点的指定出口会进入哪个目标地点和入口。

本次没有实现 NPC、CharacterState、NPC 日程、离屏模拟、路线选择、旅行时间、距离、路径成本、动态道路封锁、天气或事件对道路的影响，以及世界地图 UI。

## WorldDefinition

`WorldDefinition` 是独立 Autoload，并在 WorldState 与 WorldTime 之前加载。它负责静态世界结构；WorldState 继续只负责本次运行中已经成立和变化的世界事实。

WorldDefinition 初始化时建立全部 LocationDefinition，完成静态校验后建立以稳定 ID 查询的索引。当前公开查询包括：

- `has_location(location_id)`；
- `get_location(location_id)`；
- `get_scene_path(location_id)`；
- `get_outgoing_edges(location_id)`；
- `get_edge(location_id, edge_key)`。

查询未知 Location 或未知 Edge 时返回明确的空失败结果并输出包含 ID 的错误，不依赖目标 Scene 当前是否加载。

## LocationDefinition 与有向边

LocationDefinition 是普通静态定义数据，包含：

```text
location_id
display_name
scene_path
outgoing_edges: Array[LocationEdgeDefinition]
```

LocationEdgeDefinition 只包含：

```text
edge_key
to_location
to_entry
```

边属于所在 LocationDefinition，因此不重复保存 `from_location`。`edge_key` 只要求在所属 Location 内唯一。当前边没有 time、travel_minutes、distance 或 travel_cost。

## 当前世界目录

| location_id | display_name | scene_path |
| --- | --- | --- |
| `tavern` | 酒馆 | `res://scenes/tavern.tscn` |
| `town_street` | 小镇街道 | `res://scenes/town_street.tscn` |
| `tavern_yard` | 酒馆后院 | `res://scenes/tavern_yard.tscn` |

当前四条有向边为：

| 所属 Location | edge_key | to_location | to_entry |
| --- | --- | --- | --- |
| `tavern` | `front_door` | `town_street` | `tavern_entrance` |
| `town_street` | `tavern_door` | `tavern` | `front_door` |
| `tavern` | `back_door` | `tavern_yard` | `tavern_entrance` |
| `tavern_yard` | `tavern_door` | `tavern` | `back_door` |

双向连接由四条独立有向边明确表达，没有自动生成反向边。

## Scene、Exit 与 Entry

GridScene 根节点继续声明稳定 `location_id`，负责格子地图、碰撞、世界对象、入口坐标与出口触发区域。Location 的 `display_name` 与 `scene_path` 已统一由 LocationDefinition 提供，不再由每个 GridScene 或 LocationExit 重复保存。

新增 LocationEntry，继承 Marker2D，只声明稳定 `entry_id`。当前入口为：

- Tavern：`start`、`front_door`、`back_door`；
- Town Street：`tavern_entrance`；
- Tavern Yard：`tavern_entrance`。

LocationExit 现在只保存自己的格子触发区域和 `edge_key`。原有 `target_scene_path` 与 `target_entry` 已删除。出口进入 Tree 时确认自己属于 GridScene，并验证 `current location_id + edge_key` 确实存在于 WorldDefinition；玩家进入后只把 edge key 交给 Game。

## 图驱动的 Location 切换

Game 的初始地点使用 `INITIAL_LOCATION_ID = tavern`，通过 WorldDefinition 查询初始 Scene。之后的场景切换流程为：

1. 从当前 GridScene 取得 `location_id`；
2. 使用 LocationExit 的 `edge_key` 查询边；
3. 从边取得 `to_location` 和 `to_entry`；
4. 通过目标 LocationDefinition 查询 `scene_path`；
5. 加载并实例化目标 GridScene；
6. 验证 Scene 的 `location_id`、Scene 来源、Entry 和 LocationExit；
7. 按 `to_entry` 查找 LocationEntry；
8. 全部成功后才卸载当前 Location；
9. 把玩家放到该 Entry 的实际世界位置，并更新镜头和 Location HUD。

切换接口不再接受可绕过世界图的任意 Scene 路径和入口组合。目标定义或 Scene 无效时，当前 Location 不会先被销毁。

## 定义与 Scene 校验

WorldDefinition 初始化校验：

- `location_id` 非空且全世界唯一；
- `display_name` 非空；
- `scene_path` 非空、存在并可作为 PackedScene 加载；
- `edge_key` 非空且在所属 Location 内唯一；
- `to_location` 非空且存在于当前 WorldDefinition；
- `to_entry` 是非空稳定标识。

Location Scene 实例化后继续校验：

- 请求的 LocationDefinition 与 Scene 声明的 `location_id` 一致；
- Scene 来源路径与定义的 `scene_path` 一致；
- Scene 中每个 LocationExit 的 `edge_key` 存在于当前 Location 的出边；
- Definition 中每条 outgoing edge 的 `edge_key` 都能在所属 Location Scene 中找到对应 LocationExit；
- LocationEntry 的 `entry_id` 非空且在该 Scene 中唯一；
- 每条 outgoing edge 的 `to_entry` 都能在对应目标 Location Scene 中找到。

WorldDefinition 在静态 Definition 校验和索引建立后，会实例化全部 Location Scene 进行一次完整 Scene Graph 一致性校验。运行中实际加载 GridScene 时仍会重复验证该 Scene 自身的身份、Entry 和 Exit，场景切换前也继续确认本次目标 Entry。

错误信息会结合具体情况输出 `location_id`、`edge_key`、`to_location`、`to_entry` 和 Scene 路径。未知查询和错误定义不会静默产生可用图数据。

## 修改文件

新增：

- `scripts/world_definition/location_definition.gd`；
- `scripts/world_definition/location_edge_definition.gd`；
- `scripts/world_definition/world_definition.gd`；
- `scripts/location_entry.gd`；
- `docs/v5_development_log.md`。

修改：

- `project.godot`：登记 WorldDefinition Autoload；
- `scripts/grid_scene.gd`：增加 Definition/Scene 校验和 Entry 查询；
- `scripts/location_exit.gd`：移除目标路径与入口，只保留 edge key；
- `scripts/game.gd`：改为完全通过 Location Graph 切换；
- `scenes/tavern.tscn`、`scenes/town_street.tscn`、`scenes/tavern_yard.tscn`：迁移 Exit 与 Entry 声明；
- `docs/design.md`、`docs/architecture.md`：记录静态世界图及职责边界；
- `README.md`：更新当前状态与文档入口。

## Godot 4.7.1 实际验证

通过 WorldDefinition 查询当前没有 Scene Node 的 `tavern_yard`，成功得到显示名、Scene 路径和一条出边；查询 `tavern/front_door` 正确得到 `town_street/tavern_entrance`。

实际构造错误定义并完成拒绝验证：

- 未知 location ID 与 edge key 返回空结果并明确报错；
- 重复 location ID、重复局部 edge key、无效 Scene 路径、未知 `to_location` 和空 `to_entry` 均在 Definition 校验阶段被发现；
- 请求 Location 与实际 Scene 的 `location_id` 不一致时被拒绝；
- Scene 中 LocationExit 引用未定义 edge key 时被拒绝；
- Definition 临时增加一个 Scene 中不存在对应 LocationExit 的 edge key 时被拒绝，错误包含 `location_id` 与 `edge_key`；
- 非空但不存在的 `to_entry` 在目标 Scene 实例化后被拒绝。

当前四条正常 outgoing edge 均确认同时具有所属 Scene 的 LocationExit，以及目标 Scene 中真实存在的 LocationEntry。

使用玩家实际走入 LocationExit 验证四个方向：

- Tavern `front_door` → Town Street `tavern_entrance`；
- Town Street `tavern_door` → Tavern `front_door`；
- Tavern `back_door` → Tavern Yard `tavern_entrance`；
- Tavern Yard `tavern_door` → Tavern `back_door`。

四次切换均通过 WorldDefinition 查询目标 Scene，并通过 Scene 身份及 Entry 校验；玩家落点与既有空间行为一致。

回归验证同时确认：Player 四方向连续移动与禁止对角速度正常；Chest、Sign、Bed、WorldAction、ActionSpatialRule、WorldState 和 WorldObjectState 正常；Chest 状态跨 Location Scene 保持；Sleep 仍推进统一 WorldTime 到下一天 08:00；WorldTime 跨全部 Location 切换持续存在；Time HUD 正常读取时间。

非 headless 的 Godot 4.7.1 游戏窗口也已正常启动并退出，WorldDefinition、WorldState、WorldTime、主场景和初始 Tavern 加载期间没有脚本错误或失效引用。

## 当前限制

WorldDefinition 当前在项目启动时建立固定静态目录，不支持运行中添加或删除 Location，也没有动态边状态。Location Graph 只回答直接可达关系与进入落点，不计算路线、旅行时间、距离或成本，也不替代实际场景内的角色移动。
