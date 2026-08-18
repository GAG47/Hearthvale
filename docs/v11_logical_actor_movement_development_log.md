# V11：Logical Actor Movement 开发日志

日期：2026-08-18

## 目标与边界

V11 在现有 Actor、ActorState、LocationRuntime、World Runtime 与 Location Prepare → Commit 架构上增加正式逻辑移动。Movement Request 只表达一个普通 Actor 与其当前 Location 内的 `target_cell: Vector2i`，不建立平行 Actor、Location、Occupancy World 或 Scene Navigation Layer。

正式事实流为：

```text
Actor + target_cell
  ↓
AStarGrid2D
  ↓
Causal-PIBT
  ↓
LogicalMovementRuntime
  ↓
ActorState.local_position
  ↓
ActorRepresentation（存在时）
```

本轮没有加入 Schedule、Goal、Behavior Tree、NPC AI / LLM、跨 Location Move、自动前往 Entity / UseSlot、RHCR、SIPP、Reservation、Edge Reservation、CBS / ECBS、Joint MAPF、ORCA / RVO、congestion guidance 或 traffic optimization。

## Player 与 Actor 的统一关系

Player 继续是普通 Actor。没有增加 PlayerDefinition、PlayerState、PlayerMovementState、PlayerEntity、PlayerInventory 或 `is_player` 字段。PlayerController 只负责向一个 Actor 提供玩家输入，并把该 Actor 登记为 external movement control；Actor 的 Definition、State、位置、速度、交互与占格继续与其他 Actor 使用同一套系统。

原 PlayerController 私有 `move_speed` 已迁移为 `ActorDefinition.move_speed`。PlayerController 与 LogicalMovementRuntime 都从受控 Actor 的同一份 Definition Resource 读取基础速度，Player 与 Martha 当前数据均为 `140.0`，测试 Actor 可以通过复制 Definition 使用不同速度。

## LogicalMovementRuntime 与 Movement Request

`LogicalMovementRuntime` 作为 Autoload 独立于任何 Location Scene 运行。它持有当前 Movement Requests、external movement control 登记和单调 movement clock，不保存第二份 Actor 或 Location 数据。

每个 `ActorMovementRequest` 保存：

- Actor 引用与请求开始时的 Location instance UUID；
- 当前 Location 内的 `target_cell`；
- contracted / requesting / extended phase；
- 当前 `tail_cell` 与请求或获批的 `head_cell`；
- 单格连续位移的 `step_start_position` 与 `step_target_position`；
- 基础请求开始时间与 instance UUID 稳定决胜信息；
- 当前协调过程中的临时有效 priority；
- 当前一步按 A* 排序的候选 Cells。
- requesting 已完成协调、但仍在等待下游释放 head Cell 的批准状态。

Request 完成、取消、Actor 离开原 Location 或改由外部控制后会从 participant 集合移除，对应 movement priority 与 phase occupancy 不再存在。

## Grid A* 静态路线

每次 participant 从 contracted 准备下一步时，Runtime 从当前 LocationRuntime 建立 `AStarGrid2D`：

- region 直接使用 LocationDefinition.grid_size；
- diagonal mode 固定为 NEVER，启发式使用 Manhattan；
- Ground 缺失或不可通行的 Cell 为 solid；
- blocking Structure 为 solid；
- blocking Furniture / 其他非 Actor Entity 为 solid；
- Ground movement_cost 写入 point weight scale；
- 动态 Actor 不成为永久静态墙。

这些信息全部来自 Location Definition + LocationState sparse overrides + EntityRegistry 的当前逻辑查询，不读取 TileMap Node、Physics Collision、NavigationAgent2D、NavMesh 或 Scene。

Runtime 取得当前 tail 的四向静态合法邻格，排除无法从该邻格到达 target 的候选，按 A* 剩余 cost 排序，并确保全局 A* 推荐的 next Cell 最高优先；WAIT 永远放在最后。PIBT 如果让 Actor 临时偏离主路径，下一次 contracted 会从新 tail 重新建图和排序。

## Causal-PIBT 核心

三阶段 occupancy 固定为：

```text
contracted  → {tail}
requesting  → {tail}，head 另作为 movement claim
extended    → {tail, head}
完成一步    → {new tail}
```

连续坐标即使已经跨过 Cell 边界，extended 完成前也不会提前释放旧 tail。

基础 priority 首先比较 Movement Request 开始时的 movement clock，越早越高；同一 clock 使用 Actor instance UUID 字符串顺序稳定决胜。协调按基础 priority 处理 requesting participants。请求的候选 Cell 被另一个 participant 占据时，阻挡者临时继承当前更高 priority，并递归尝试自己的 A* 排序候选，形成当前一步的局部依赖链。

每次尝试候选前，Runtime 快照保存 assignments、head owners、递归 status，以及所有 Request 的 phase、head、candidates、临时 effective priority 与协调批准状态。下游无法得到合法非冲突 assignment 时完整恢复快照，上游继续尝试下一个候选；所有移动候选失败后才 WAIT。

协调成功后不会把整条依赖链同时切换为 extended。只有 head 当前没有 phase occupancy 的依赖叶节点先开始连续移动；上游保持 requesting 与已批准 head claim。叶节点真正完成、收缩到新 tail 并释放旧 tail 后，直接上游才进入 extended，依次形成因果释放顺序。因此即使链中 Actor 的 move_speed 不同，也不会出现前后 Actor 同时用 extended 声明同一个中间 Cell。

V11 实现的是 Causal-PIBT 核心局部协调，不承诺解决所有死胡同、狭窄拓扑循环或长期拥堵。没有为了绝对活性加入未来时间规划、reservation、特殊 dead-end 规则或 congestion cost。

## 连续 ActorState 移动

获批步骤进入 extended 时记录 Actor 当前真实 `local_position`，目标坐标为：

```text
step_target_position
= step_start_position + Vector2(head - tail) * GridSpace.CELL_SIZE
```

推进使用 `move_toward` 与 ActorDefinition.move_speed，因此不会先吸附到 Cell 中心，并完整保留原格内 offset。每个 Actor 独立完成自己的 extended phase；不同速度不需要同步 timestep。真正到达 step target 后才令 `tail = head`，回到 contracted 或在到达最终 target 时清除 Request。

## Dynamic Actor Occupancy 与 PlayerController

LocationRuntime 查询 Actor Cell 时委托 LogicalMovementRuntime：participant 使用 phase occupancy，非 participant 使用 ActorState 派生的 `current_cell`。Location Entry 还会把 requesting head 视为 movement claim，避免 Transfer Prepare 把迁入 Actor 放入即将使用的 Cell。

PlayerController 控制的 Actor 登记为 external movement control，因此：

- 仍通过同一个普通 Actor `current_cell` 参与 occupancy；
- 不能提交 Logical Movement Request；
- 不加入 PIBT priority inheritance 或 backtracking；
- NPC 不能推走或替它决定移动；
- NPC 只能绕行或 WAIT，并在该 Actor 离开后继续。

这不是 Player 专属 occupancy 类型，任何当前由外部连续控制器接管的 Actor 都使用同一登记语义。

## Representation 与离屏运行

ActorRepresentation 增加明确的 State-driven / Representation-driven 边界。普通 Actor 与 Logical Movement participant 由 ActorState 驱动 Representation；PlayerController 当前直接控制的 Representation 才把位置同步回 ActorState。

NPC 所在 Location Scene 被销毁时，Representation 不会把旧位置反写回逻辑 State。LogicalMovementRuntime 继续在 Autoload physics process 中更新 ActorState；之后重建 Location Scene 时，新的 ActorRepresentation 直接从当时的 ActorState.local_position 创建，因此加载与未加载 NPC 不存在两套移动算法。

## Location Entry 多 arrival Cells

LocationEntry 的单一 `cell` 已迁移为有序 `arrival_cells: Array[Vector2i]`。Tavern、Tavern Yard 与 Town Street 的现有 Entry 都迁移为单元素数组，保持原行为。

Location Transfer Prepare 按 Definition 顺序检查候选：

- 必须位于 Location bounds 内；
- Ground 必须可进入；
- Structure 与 blocking Furniture / Entity 不得阻挡；
- 不得存在 Actor phase occupancy；
- 不得存在 requesting head movement claim。

找到首个合法 Cell 才继续生成和预检目标 Scene。全部不可用时 Prepare 返回失败，不修改迁移 ActorState、不释放旧 Scene、不推开或取消 NPC，并由正常 Location Change 路径提示“此路不通。”。

## 验证范围

V11 专项测试覆盖：

- 单 Actor 四向 A* 与连续 Vector2 位移；
- 原格内 offset 保留，以及跨 Cell 边界后 extended 仍占 tail + head；
- Ground movement cost 路线选择；
- 不同 move_speed 的独立完成时间；
- contracted、requesting、extended 与完成后的 occupancy；
- 同目标请求的稳定 priority 决胜；
- 多 Actor priority inheritance 依赖链；
- 依赖叶到根的因果 extended 顺序与全程无重叠 occupancy；
- 下游失败后的 snapshot backtracking 与替代候选；
- external Actor 的绕行、WAIT、离开后恢复及不可被 PIBT 移动；
- requesting head movement claim 对 arrival selection 的阻挡；
- Scene 卸载期间继续移动与重建后的 Representation 同步；
- Player 仍使用普通 ActorDefinition / ActorState 和共享 move_speed；
- 多 arrival Cells 的顺序选择与全部占用时 Prepare 拒绝。

最终回归结果：

- ActorDefinition Resource：29 checks passed；
- EntityRegistry：24 checks passed；
- V8 Entity Representation System：41 checks passed；
- FurnitureDefinition Resource：27 checks passed；
- V7.4.1 Entity architecture cleanup：112 checks passed；
- V7.5 Location Prepare to Commit：39 checks passed；
- Project Definition Resources / V9：2230 checks passed；
- V10 Entity Interaction Space：132 checks passed；
- V11 Logical Actor Movement：161 checks passed；
- 主场景 headless smoke：正常启动并以 exit code 0 退出。

EntityRegistry、Entity Representation、V7.5 与 V11 测试中的错误日志来自各自明确执行的失败分支断言，不是未处理回归。
