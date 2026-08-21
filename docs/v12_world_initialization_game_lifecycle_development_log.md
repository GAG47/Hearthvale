# V12 World Initialization & Game Lifecycle 开发记录

## 版本基线与范围

本轮基于 `bf4b520`（`v11.5`）实现。V12 只整理 New Game World 的完整创建、Game lifecycle、world-scoped runtime ownership、固定更新和跨系统 Location transition 时序；没有实现 Save / Load、PCG、Schedule、NPC AI、Economy，也没有增加 World / Service / EventBus / DI 等通用 Framework。

## NewGameSetup 与多态 Spec

旧 `ProjectWorld`、`ProjectLocationInstanceSpec` 与 `project_world.tres` 已直接迁移为：

```text
NewGameSetup
├─ initial_total_minutes
├─ location_specs: Array[NewGameLocationSpec]
├─ entity_specs: Array[NewGameEntitySpec]
└─ controlled_actor_spec: NewGameActorSpec

NewGameEntitySpec
├─ instance_id
├─ initial_location: NewGameLocationSpec
└─ local_cell
    ↑
    ├─ NewGameActorSpec: ActorDefinition + initial_facing
    └─ NewGameFurnitureSpec: FurnitureDefinition
```

`data/world/new_game_setup.tres` 保留原 Player、Chest、Sign、Bed 的 Definition、instance UUID、Location、Cell 与 Player Facing，以及 Tavern、Town Street、Tavern Yard 的 Location UUID 和 Definition 引用。Entity initialization 只有统一 `entity_specs`；Game 主循环只调用 Spec 的 `create_initial_state()` / `create_entity(state)`，没有 Player / Furniture subtype 分支。

Spec 验证自己的 ID、Definition、Location、Cell、Actor facing 或 Furniture footprint；NewGameSetup 验证 Location / Entity UUID 唯一性、initial Location membership、controlled Actor membership、Edge target、Entry target，以及初始 Actor terrain、Actor overlap 与 blocking Entity placement。LocationDefinition 自己验证 grid、layer、edge、entry 和 exit 的通用结构。

## Game lifecycle 与初始化顺序

Game 当前 lifecycle 为：

```text
EMPTY → INITIALIZING → RUNNING → ENDING → EMPTY
```

`initialize_world()` 只接受 EMPTY。实际初始化顺序是：验证 NewGameSetup；创建三个空 Registry；注册 GameTimeState、全部 LocationState、全部 EntityState；创建全部 Location；创建全部 Entity；验证 runtime relationship；创建并注入 GameClock 与 LogicalMovement；解析 controlled ordinary Actor；绑定 PlayerController；连接 World signals；Prepare / Validate / Commit 初始 Location Representation；刷新 Camera / HUD；最后进入 RUNNING。

初始化任意阶段失败都调用 `end_world()`。teardown 先进入 ENDING 停止 fixed update，再清除 pending transition 与 Player intent、取消全部 Movement、解绑 PlayerController、销毁 LocationScene、断开 World signals、释放 LogicalMovement / GameClock、clear Entity / Location / State Registry、清空 Game World references，最后返回 EMPTY。正常结束与初始化失败没有平行 cleanup。

## World-scoped runtime 与显式依赖

StateRegistry、EntityRegistry、LocationRegistry、GameClock 与 LogicalMovement 已从 `project.godot` 的 Autoload 全部删除并改为 `RefCounted`。Game 每次初始化创建新实例，每次 end 清除并释放引用。

LocationRegistry 现在只登记和查询已存在 Location，并委托当前 Edge / target Entry 查询。它不 preload New Game 数据、不缓存 Project key、不索引 Definition、不创建 State / Location，也不拥有 World lifecycle。三个 Registry 都新增或保留明确的 enumerate 与 `clear()`。

GameClock 构造时接收已经存在的 GameTimeState，以 `advance(delta)` 消费 simulation delta；旧 `_ready()`、`_process()`、StateRegistry lookup、REAL 命名已删除。LogicalMovement 构造时接收 LocationRegistry 与 EntityRegistry；旧 `_ready()`、`_physics_process()` 和 dependency resolver 已删除，Causal-PIBT 算法未重写。

repository-wide 的 world runtime 全局查找已清除：PlayerController 使用 Game bind 的 Registry / Movement / Clock；EntityAction 显式携带 ActionSpatialRule 与 SleepableBehavior 所需 runtime；LocationSceneBuilder / Factory 把 LogicalMovement 显式传给 ActorRepresentation。业务脚本不再用 `/root`、Engine main loop 或 SceneTree root 寻找这五个对象。

## 固定更新、Player intent 与 Location transition

Game 是唯一 World fixed simulation 驱动入口，RUNNING 时顺序固定为：

```text
PlayerController.consume_world_intent(game_clock)
GameClock.advance(delta)
future world-system placeholder
LogicalMovement.advance(delta)
process pending Location transition
```

PlayerController 删除自己的 `_physics_process()`。held direction 在 Game Player Intent Phase 读取并提交；一次性 interaction 由 `_unhandled_input()` 缓存，到同一 phase 消费。`_process()` 只同步 Camera / visual。

controlled Actor 完成 Exit Cell step 时，`step_completed` callback 只记录 pending transition，并立刻把其 direction intent 清零，阻止同一次 Movement advance 后半段创建下一请求。LogicalMovement 完成内部收尾并 return 后，Game 才同步执行 Location Prepare → Validate → Commit。旧 `_perform_location_change.call_deferred()`、participant `await physics_frame` 与 commit 后额外 `await physics_frame` 已全部删除；当前没有 world-scoped coroutine，因此没有增加 generation / epoch / cancellation 机制。

## 验证结果

新增 `test_v12_world_lifecycle.gd`，覆盖 NewGameSetup、Spec 多态、Registry clear、GameClock explicit advance、LogicalMovement explicit dependencies、PlayerController intent phase、prepare failure safety、Exit pending transition、持续 direction 停止、`initialize → end → initialize`、晚阶段初始化失败 teardown 以及移除 Autoload / async patch 的源码边界。

历史测试已从 Autoload 改为显式创建 runtime 或读取测试 Game 拥有的 runtime。最终测试结果与 smoke 结果记录在本次交付报告中；本日志只描述实现，不声明后续 Save / Load 或 PCG 已完成。
