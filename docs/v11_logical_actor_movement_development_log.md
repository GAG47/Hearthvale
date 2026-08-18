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

## V11.1 修正：Unified Grid Movement + Formal Causal-PIBT

日期：2026-08-18

本节记录 V11 初版之后的修正，不回写上文的历史实现状态。V11.1 处理了两个根本问题：初版 Player 仍由 ActorRepresentation 自由连续移动；初版局部协调以递归 resolver、VISITING status 与 snapshot/restore 模拟 priority inheritance/backtracking。两者均已替换。

### 统一 Actor Grid Movement

Player 与 NPC 现在都通过同一个 `LogicalMovementRuntime`，一次正式移动固定为：

```text
contracted(A)
→ requesting(A, B)
→ extended(A, B)
→ contracted(B)
```

`B` 必须是 `A` 的上下左右相邻 Cell。contracted Actor 必须位于 `GridSpace.cell_to_local_position(A)`；进入 extended 时起点和目标都使用 tail/head 的标准坐标，ActorState.local_position 在两者之间按 `ActorDefinition.move_speed` 连续推进，完成后精确写入 head 标准坐标。不同 Actor 仍按各自速度独立完成，不建立统一 Movement Tick。

PlayerController 不再设置 Representation velocity、不调用 `move_and_slide()`、不把 Representation 位置同步回 ActorState。它只把最新四向输入写为 direction intent。持续按键时，每个 Cell 仍是独立 Request，但前一步完成后立即从新 tail 创建下一步；extended 中改变方向不会中断当前步，完成后使用最新缓存方向；释放输入会完成当前步再停止。

NPC target intent 继续使用 AStarGrid2D 生成全局 guidance：合法四向邻格按到 target 的剩余路径成本排序，A* 推荐 next Cell 优先，最后追加 WAIT。direction intent 的候选只包含指定邻格与 WAIT，因此 Causal-PIBT 不会替玩家自动选择另一方向。这个差异来自 intent kind，不来自 Player 身份字段。

ActorRepresentation 现在对所有 Actor 都是单向表现：

```text
Controller / Pathfinding
  ↓
LogicalMovementRuntime
  ↓
ActorState
  ↓
ActorRepresentation
```

原 `_state_driven`、external movement control、`sync_state_from_representation()` 与相关切换入口均已删除。Scene 卸载后 LogicalMovementRuntime 继续推进 ActorState；重建 Scene 时 Representation 直接恢复当前状态。

### 正式 Causal-PIBT participant 状态

`ActorMovementRequest` 现在直接维护：

- contracted / requesting / extended；
- tail / head；
- original priority 与 current/inherited priority；
- parent 与 children；
- 当前有序候选 `C_i`；
- 当前搜索/排除集合 `S_i`；
- intent kind、direction cache 以及连续一步的标准起止位置。

每次 activation 对一个 participant 执行正式状态迁移。高优先 requesting Actor 指向另一个 participant 的 tail 时，阻挡者建立 parent 关系、登记为 parent child、继承 current priority，并复制 parent `S_i` 后继续从过滤后的 `C_i` 搜索。child 无候选时把 `S_i` 传播回 parent，过滤 parent 剩余 `C_i` 并令 parent 回到 contracted；parent 随后尝试剩余候选。child head 已存在于 parent `S_i` 时按 request-cycle 规则回到 contracted，不依赖递归 VISITING 标记。

相同 head 的 requesting contenders 使用 current priority 只选一个 winner。依赖链中 head 仍被任何 hard occupancy 占据时，上游保持 requesting；只有空闲 head 的叶节点先进入 extended。叶节点释放 tail 后，上游才按因果顺序继续。因此不同 move_speed 不会让依赖链重叠占格。

初版以下机制已删除：

- `STATUS_VISITING / STATUS_RESOLVED / STATUS_FAILED`；
- 递归 `_resolve_movement()`；
- assignments / head owners / recursion context；
- Request coordination snapshot/restore；
- Player external movement control 特例。

没有增加 retry_count、blocked_time、deadlock_counter、corridor/dead-end special case、reservation 或 congestion 规则。

### Hard Occupancy 修正

V11.1 的正式语义为：

```text
contracted(A)      occupied = {A}
requesting(A, B)   occupied = {A}
extended(A, B)     occupied = {A, B}
contracted(B)      occupied = {B}
```

requesting head 只是协调意图，不再通过 `is_actor_cell_claimed` 对外形成 occupancy。Location Entry 的 `arrival_cells` 只避开 contracted Cell 与 extended tail/head；如果某 Cell 仅被另一个 Request 指为 head，Transfer Prepare 仍可选择该 Cell。若 Player 已进入 extended，Location Change 会先清除持续方向 intent，等待当前完整单步结束，再执行 Transfer，避免半格迁移。

### 当前限制与边界

V11.1 没有正式初始化 Martha，也没有新增 NPC bootstrap、spawn list、Schedule、Goal、AI、随机移动或第二套 Movement Grid。

当前只有持有 Movement Intent 的 Actor 是可继承 participant；没有 intent 的静止 Actor 作为 hard obstacle，不会被系统擅自生成移动目标。没有空闲节点或剩余合法候选时，正式结果可以是 WAIT。普通 Causal-PIBT 的局部模型不保证解决所有死胡同、满占拓扑或长期拥堵；本轮没有加入 RHCR、SIPP、Reservation Table、Edge Reservation、CBS / ECBS、Joint MAPF、ORCA / RVO、Temporary Priority extension、congestion guidance、traffic optimization 或特殊死锁规则。

### V11.1 验证

专项测试重建为统一 Grid Movement 语义，覆盖：

- Player 与 NPC 共用 LogicalMovementRuntime；
- PlayerController intent-only 与 ActorRepresentation 单向表现；
- cardinal-only、标准落格、平滑中间位置与长距离无漂移；
- held direction 连续移动、extended 中最新方向缓存与释放后停止；
- direction `C_i` 仅指定方向 + WAIT，target `C_i` 保留 A* 多候选；
- contracted/requesting/extended hard occupancy；
- requesting head 不阻挡 Location Entry；
- same-head current priority 决胜；
- parent/children 建立与释放；
- original/current priority、`C_i/S_i` 传播、inheritance 与 backtracking；
- request-cycle recovery 不依赖 STATUS_VISITING；
- 不同 move_speed、Scene unload 与 Representation rebuild；
- 未正式初始化 Martha；
- 旧 resolver 与 external control API 的静态删除检查。

当前专项结果为 `V11.1 Unified Grid Movement: 175 checks passed.`。V7.4 测试已同步移除自由移动与 Representation 回写假设，改为验证完整单格移动和逻辑阻挡；V7.5、V9、V10 以及基础 Definition / Registry / Representation 回归保持通过。

## V11.1 最终架构修正：Cell-Authoritative Entity State

日期：2026-08-18

本节记录 V11.1 正式 Causal-PIBT 完成后的最后一轮空间权威修正，不回写前述 V11 / V11.1 历史实现。Causal-PIBT 的 parent/children、original/current priority、`C_i`、`S_i`、inheritance、backtracking 与 request-cycle 主体没有重新设计；本轮只删除 Logical World 中残留的连续坐标权威，并修正 Representation、Facing 与 Spatial Action 的集成。

### EntityState 与 Location Logical World

所有 Location Entity 的正式位置已从 `EntityState.local_position: Vector2` 迁移为 `EntityState.local_cell: Vector2i`。`Entity.current_cell` 直接返回 `state.local_cell`，不再调用 pixel-to-cell 转换。旧 `Entity.local_position` 与 `GridSpace.local_position_to_cell()` 已删除，因此 Logical World 不存在可与 Cell 冲突的第二位置真相。

Furniture 的 `local_cell` 明确定义为 footprint origin：world occupied Cell、UseSlot 与 SlotEntrance 都由 origin 加 Definition-local Cell 得到。FurnitureRepresentation 独立根据 footprint bounds 计算视觉中心，不会在 physics process 或退出 Scene 时把 Node2D position 写回 State。

现有 Player 与 Furniture 初始化数据全部改为 Cell；Location Transfer Prepare 只传递 `spawn_cell`，Commit 直接写入 `ActorState.local_cell`。LocationEntry 的 Scene Marker 使用 arrival Cell center 仅作显示；arrival 选择继续只检查静态合法性与 Actor hard occupancy，requesting head 不构成阻挡。

### Step Progress 与 Cell Commit

`ActorMovementRequest` 删除 `step_start_position` / `step_target_position`，改为保存：

- `tail_cell` / `head_cell` / phase；
- `step_elapsed`；
- `step_duration`；
- 由 `elapsed / duration` 得到的归一化 progress。

`step_duration = GridSpace.CELL_SIZE / ActorDefinition.move_speed`。LogicalMovement 在 extended 中只增加 elapsed，不逐帧修改 ActorState Vector2。正式 Cell 语义为：

```text
contracted(A)      ActorState.local_cell = A   occupied = {A}
requesting(A, B)   ActorState.local_cell = A   occupied = {A}
extended(A, B)     ActorState.local_cell = A   occupied = {A, B}
progress >= 1      ActorState.local_cell = B   occupied = {B}
```

因此 `current_cell` 在 extended 期间仍是 committed tail；完整 occupancy 必须继续从 Movement tail/head/phase 查询。不同 move_speed 只产生不同 duration，不重新引入逐帧逻辑坐标。

### Representation 与 Scene 生命周期

`GridSpace.cell_to_local_position()` 保留 Cell origin 语义，并新增 `cell_to_center_position()`。ActorRepresentation 在 contracted 时显示于 committed Cell Center；extended 时显示于：

```text
lerp(cell_center(tail), cell_center(head), progress)
```

插值结果只属于 Scene，不写回 ActorState。LocationSceneBuilder 与 EntityRepresentationFactory 现在传递 Cell 而不是 pixel target position。Scene 卸载期间 LogicalMovement 继续推进 elapsed/duration；Scene 在 extended 中途重建时，ActorRepresentation 直接读取现有 tail/head/progress 恢复正确插值位置，不会从 0 重新播放。

### Facing 与 Spatial Action

PlayerController 仍只产生 direction intent。方向输入先立即更新普通 `ActorState.facing`，再尝试提交相邻 Cell Step；即使墙、Furniture 或其他 Actor 阻挡移动，玩家仍留在原 Cell，但可以正确转身并执行面对目标的 V10 Interaction。

ActionSpatialRule 增加统一世界规则：contracted 与 requesting Actor 在满足 UseSlot / facing 条件时仍可开始 Spatial Action；extended Actor 以 `actor_in_cell_transition` 拒绝，因为它正在两个 Cell 间迁移，不稳定占据单一 Slot Cell。Interaction 全程只消费 Logical Cell、Facing、UseSlot、SlotEntrance 与 LocationRuntime，不读取动画像素位置。

### 验证与边界

V11.1 专项测试新增或修正了以下覆盖：

- EntityState 只有 `local_cell`，`current_cell` 直接来自 committed Cell；
- contracted / requesting / extended 的 local_cell 与 hard occupancy；
- 25%、50%、99% progress 均保持 tail，完成时一次 Commit 到 head；
- elapsed / duration / progress 与不同 move_speed duration；
- 长距离移动只提交整数 Cell，不存在 pixel-to-cell 累计漂移；
- contracted Cell Center、extended center-to-center 插值；
- Scene 中途卸载、extended 中途重建与离屏完成；
- 阻挡方向输入仍立即改变 facing，并可面对 blocking Furniture 交互；
- contracted / requesting UseSlot Action 保持有效，extended 正式拒绝；
- requesting head 不阻挡 Location Entry；
- inheritance、backtracking、request-cycle 与 same-head 决胜继续通过。

本轮没有正式初始化 Martha，没有增加 NPC bootstrap、Schedule、Goal、AI、随机移动、第二套 Movement Grid、Reservation、Congestion Guidance 或 corridor/dead-end 特例。正式 Causal-PIBT 仅做适配 Cell-authoritative State 所必需的 Step commit 修改。

最终回归结果：ActorDefinition 29、EntityRegistry 24、Entity Representation 41、FurnitureDefinition 27、V7.4.1 119、V7.5 39、V9 2230、V10 132、V11.1 200 checks 全部通过；主场景 headless smoke 以 exit code 0 退出。Registry、Representation 与 V7.5 输出中的 error 日志来自测试明确覆盖的预期失败分支。
