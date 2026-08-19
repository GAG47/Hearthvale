# V11.3 — Location Naming & Responsibility Cleanup 开发日志

## 本轮范围

V11.3 只整理现有 Location、Registry、Scene 与游戏时间的正式名称和职责边界，不增加玩法，也不开始 V12 世界初始化。本轮没有初始化 Martha 或其他 NPC，没有增加 AI、Schedule、Goal、Save / Load 或 PCG，也没有修改 Causal-PIBT 算法与 V10 Interaction 设计。

## Location 正式模型

当前关系正式固定为：

```text
LocationDefinition + LocationState + EntityRegistry
  ↓
Location
  ↓
LocationSceneBuilder
  ↓
LocationScene
```

`LocationRuntime` 已直接改为 `Location`，没有 alias、wrapper 或兼容类。Location 只持有 LocationDefinition、LocationState 与 EntityRegistry，并继续回答当前 Entity、committed Cell 上的 Entity、当前 Tile / Topology、UseSlot 与静态可通行性查询。

Location 已删除 LogicalMovement 引用以及混合静态规则和 Actor occupancy 的 `is_actor_cell_available()`。`get_entities_at(cell)` 只使用 Entity 当前已经提交的 `EntityState.local_cell` / footprint；extended Actor 的 State 仍在 tail，因此 Location 不会把 head 提前视为 Entity 当前位置。Movement Request、tail/head/phase、hard occupancy、priority inheritance 与 Causal-PIBT 仍只属于独立 LogicalMovement。

Location Transfer 的调用方按 Entry 顺序组合两项查询：Location 判断 bounds、Ground、Structure 和 blocking non-Actor Entity；LogicalMovement 判断 Actor hard occupancy。requesting head 不形成 hard occupancy，extended head 形成 hard occupancy。没有为此增加中间 Manager、Context、Service 或 Coordinator。

## LocationRegistry 与旧职责迁移

新增 LocationRegistry，以 Location instance UUID 登记、索引和查询当前逻辑 Location，并提供 register、has_location、get_location 与 get_all 语义。Project key → instance UUID 作为当前启动数据的 lookup alias 保留，但不是 Definition 权威。

`has_location()` 与 `get_location()` 只判断和返回已经注册的 Location 实例；Definition 索引存在但 Location 尚未实例化时，前者返回 `false`，后者返回 `null`。LocationRegistry 不保留重复的通用 `has()` 或 `_get()` 查询入口。

V11.3 收尾中，`get_location()` 已收敛为纯查询：只返回 Registry 中已经注册的 Location；不存在时返回 `null`，不会查找 Definition / State、创建 LocationState、调用 `Location.new()` 或自动注册。当前 Project Location 的创建仍由 `Game._initialize_project_locations()` 显式完成。

旧 WorldDefinitionRuntime 已完全删除，其职责分配如下：

- ProjectWorld 读取、Project Location 索引和数据校验迁入 LocationRegistry；
- LocationDefinition、LocationState 与 EntityRegistry 的组合结果由 Location 表达；
- 当前 Edge、Entry、Entries、Exits 和三层 Cell 数据查询由 Location 表达；
- 跨 Location lookup 和 Edge / target Entry 委托由 LocationRegistry 表达；
- Game 在当前启动流程中做最小 wiring：建立 Project LocationState 与 Location，并分别登记到 StateRegistry 与 LocationRegistry。

## State、Scene 与时间清理

`WorldStateRuntime` 已改为 `StateRegistry`。StateRegistry 现在只登记、持有和查询 EntityState、LocationState 与 GameTimeState；它不再在 `_ready()` 中读取 ProjectWorld 并自动创建 LocationState，也不再保存 `_active_locations`、LocationScene 弱引用或 Scene 注册 / 注销接口。Game 的 `current_location` 是当前活动 LocationScene 的唯一持有入口。

`GridSpace` 已改为 `LocationGridSpace`，继续只提供 Location Grid 的 Cell → Scene position/center 和 grid size → Scene size 转换。`GridScene` 已改为 `LocationScene`；LocationSceneBuilder 继续从逻辑 Location 构建可销毁的 Scene Representation，并自行负责 Entry Marker 的 Cell → Pixel 转换。

`WorldTimeRuntime`、`WorldTimeState` 与 `WorldCalendar` 已分别改为 `GameClock`、`GameTimeState` 与 `GameCalendar`。Autoload 当前为 LocationRegistry、StateRegistry、EntityRegistry、LogicalMovement 与 GameClock。

历史目录 `scripts/world_definition/`、`scripts/world_state/` 与 `scripts/world_time/` 已删除。Location 专属代码集中在 `scripts/location/`；StateRegistry 位于 `scripts/state/`；GameClock、GameTimeState 与 GameCalendar 位于 `scripts/time/`。ProjectWorld 与 ProjectLocationInstanceSpec 移至 `scripts/initialization/`，类名和数据语义保持不变。

## 最终命名收尾

EntityRegistry 与 LogicalMovement 继续作为现有 Autoload 使用；无独立语义的 `EntityRegistryRuntime`、`LogicalMovementRuntime` 全局类名已经删除。Actor 对目标 Entity 发起的行为统一称为 EntityAction，文件与类型不保留旧别名。

UseSlot 与 SlotEntrance 的坐标转换统一使用 Location Cell 语义。LocationScene 的矩形查询称为 `get_local_rect()`，三个表现层共用 `data/location_tileset.tres`，当前 LocationScene 挂载节点称为 LocationSceneRoot。ActorRepresentation 不再包装原生 `global_position`，Location 也不再为 `instance_id` 提供重复的 `location_id`；LocationScene 的 `location_id` 仍表示该 Scene 对应的 Location。

## LocationExitArea 状态

LocationExitArea 本轮保留，只同步 LocationScene、LocationRegistry 与 LocationGridSpace 引用。它是否仍适合正式 Grid Movement，不属于本轮命名清理结论；后续必须结合 Cell-based Location Transition 单独复查，不能把当前保留视为最终设计决定。

## Deferred to V12 — World Initialization

以下事项明确延期，本轮没有实现：

1. 重新评估 ProjectWorld 的最终名称以及是否继续存在；
2. 重新评估 ProjectLocationInstanceSpec 的最终名称以及是否继续存在；
3. 根据真实职责决定是否需要 WorldDefinition 类；
4. 根据真实职责决定是否需要 WorldState 类；
5. 根据真实职责决定是否需要 World 类；
6. 统一 Player 与普通 Actor 的正式初始化流程；
7. 把当前硬编码 Furniture 初始化移出 Game；
8. 将 Location 初始化正式纳入 Game 控制的 init 流程；
9. 统一当前各类 State 的创建流程；
10. 把当前 Runtime、Registry 与 Clock Autoload 纳入 Game 生命周期管理；
11. 由 Game 正式控制 init、update 与 end；
12. PCG Actor 直接生成 Definition + State，再进入与预定义 Actor 相同的正常 Runtime；
13. PCG Location 直接生成 LocationDefinition + LocationState，再登记为正常 Location，不要求预先写入初始 Location 数据；
14. New Game 与未来 Load Game 使用不同数据来源，Load Game 不能重新消费 Initial Data 并重置已保存世界。

ProjectWorld 与 ProjectLocationInstanceSpec 因此仍是待 V12 统一评估的初始化遗留输入，不代表最终架构命名。

## 明确未修改

本轮没有正式初始化 NPC / Martha，没有统一 Actor bootstrap，没有迁移 Game 中硬编码 Player / Furniture 内容，没有实现 Save / Load、PCG Location、PCG NPC、Schedule、AI 或 Goal，没有修改 LogicalMovement 的 Causal-PIBT 算法，也没有重新设计 V10 Interaction。
