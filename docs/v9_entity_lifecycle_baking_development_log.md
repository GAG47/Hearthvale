# V9：Entity Lifecycle / Baking

日期：2026-08-13

## 本次目标

V9 落地人工固定世界内容的完整生命周期：

```text
Placement
→ Baking
→ Initial Entity Data
→ EntityFactory
→ Entity + EntityState
→ V8 Representation System
→ Representation
```

Placement 是制作阶段 Authoring Data，EntityState 是运行世界中的权威状态，Representation 是已存在 Entity 在当前 Scene 中的临时空间表现。三个阶段保持分离。

## Placement 与 Baking

新增 EntityPlacement、ActorPlacement 与 FurniturePlacement。Placement 只保存 Definition 路径、Node2D.position，以及 Actor 的 initial_facing；Location ID 来自 Placement 所属的正式 Location Scene。Placement 不保存 UUID、State、BehaviorState、Representation 或运行时 Entity 引用。

EntityBaker 提供 `supports(placement)` 与 `bake(placement, location_id)`。ActorBaker 和 FurnitureBaker 将各自 Placement 转为可序列化 Dictionary；EntityBakerRegistry 扫描全部 Baker，只有唯一匹配才成功。Baker 不生成 UUID，也不创建 Entity、State 或 Representation。

开发工具执行命令为：

```bash
godot --headless --path . --script res://tools/bake_initial_world.gd
```

工具从 WorldDefinition 的正式 LocationDefinition 目录枚举所有 Location，加载 Scene、按稳定顺序读取 Placement、完成验证后写入 `data/world/initial_entities.json`。任何 Placement、Definition、Location、位置或 facing 错误都会使整体失败，并保留已有有效输出。

## Initial Entity Data 与运行时创建

当前 schema_version 为 1。每条 Entity 数据包含明确 `entity_type`、`definition_path`、`location_id`、`local_position`；Actor 另含 `initial_facing`。Placement 和 Initial Entity Data 都不保存运行时 UUID。

EntityFactory 提供 `supports(entity_type)` 与 `create(entity_data)`。ActorEntityFactory 和 FurnitureEntityFactory 加载对应 Definition、通过 UuidGenerator 生成世界实例的永久 `entity_id`，并创建 EntityState 与 Entity。Actor Factory 直接使用加载得到的 ActorDefinition，不再为实例复制 Definition。Furniture 继续由 Furniture 自身现有构造逻辑建立 Behavior 与 BehaviorState，没有在 Factory 中复制能力初始化。

ActorDefinition 与 FurnitureDefinition 统一使用 UUID v4 `definition_id` 标识永久内容身份；Entity / EntityState 使用独立 UUID v4 `entity_id` 标识当前世界中的具体实例。Initial Entity Data 的 `definition_path` 只负责找到 Definition，不保存或代替这两种身份。

EntityFactoryRegistry 同样要求唯一匹配。Game 读取全部 Initial Entity Data 后进入 Prepare：只按 entity_type 请求 Factory，创建并验证完整的 Entity + EntityState 批次，不修改正式 Registry。全部成功后才进入 Commit，通过 WorldState 与 EntityRegistry 的批量接口统一登记；任何中间创建或验证失败都保持两个 Registry 原样。Game 不再保存三件家具的 UUID、Definition 路径、Location 或位置，也没有按 Actor / Furniture 类型分支注册。

## 当前家具迁移

床、储物箱和告示牌已经迁移为 Tavern Scene 中三个 FurniturePlacement。Bake 输出在当前启动时创建 Furniture + FurnitureState，随后 V8 Representation System 正常创建 FurnitureRepresentation。GridScene 在正常激活前移除 Placement，因此 Placement 不进入运行时交互、碰撞、Registry、WorldState 或 Representation 流程。

Location 往返继续只重建 Representation。家具位置、OpenableState 和其他已经成立的事实从同一个 FurnitureState 恢复，不重新读取 Scene Placement。

## 验证

- V9 Entity Lifecycle / Baking 专项：93 项检查通过；
- V7.4.1 完整运行链：113 项检查通过；
- V7.5 Location Prepare → Commit：58 项检查通过；
- V8 Entity Representation System：41 项检查通过；
- Bake Initial World 成功生成三条稳定 Furniture 数据；
- 无 Baker、多个 Baker、无 Factory、多个 Factory 与错误 Placement 均明确失败；
- 错误 Placement 不覆盖已有 Baking 输出；
- ActorPlacement → ActorBaker → ActorEntityFactory → Actor + ActorState 完整链路通过；
- V9.1 Entity Lifecycle Cleanup：43 项检查通过，覆盖初始化原子性、Definition / Entity 身份分离和 Baking CLI 退出码；
- Furniture UUID、Definition、FurnitureState、BehaviorState、注册和 Representation 链路通过；
- sleep、open、close、inspect、移动、碰撞、Camera、Location 往返与失败安全保持正常；
- Baking CLI 成功返回 0，失败返回 1；
- 主场景 headless smoke 正常退出。

## 范围

Player 仍未迁入 Placement / Baking；当前 Session 启动流程直接加载 Player Definition，并为 Player Actor / ActorState 生成独立 `entity_id`。本轮没有重构 WorldTime 或完整 Game / Session 初始化，也没有实现 Save / Load、AI、Schedule、Dungeon Generator 或新的 Entity 类型。
