# V7.4：Unified Entity Architecture

## 目标

V7.4 把原先平行的 Character 与 WorldObject 体系迁移为统一逻辑实体结构：

```text
Entity / EntityState
├─ Actor / ActorState
└─ Furniture / FurnitureState

ActorPresentation
FurniturePresentation
```

Entity 与 State 是独立于 SceneTree 的运行时世界对象；Presentation 只负责当前 Location 中的视觉、碰撞和空间命中。

## Actor 迁移

Character、CharacterDefinition、CharacterState、CharacterPresentation 已直接迁移为 Actor 对应类型，目录、数据字段和调用方统一使用 `actor` / `entity_id`，不保留兼容别名。ActorDefinition 的四向静态 `visuals`、JSON Loader、UUID v4 校验和 Player / Martha 数据保持原有职责。

## EntityRegistry 与 WorldState

CharacterRegistry 已由 EntityRegistry 取代。Registry 只维护 `entity_id → Entity`，统一查询 Actor 与 Furniture，不加载 Definition、不创建 State 或 Presentation。

WorldState 统一保存 `entity_id → EntityState`。Runtime Entity 持有的 State 与 WorldState 登记的是同一对象；ActorState 保留 facing，FurnitureState 当前保存 `is_open`。WorldTimeState 继续作为独立的世界级状态存在。

## Furniture 与 Behavior

Bed、Chest、Sign 的 WorldObject 类和独立 Scene 已删除，迁移为三份 FurnitureDefinition JSON：`simple_bed`、`wooden_chest`、`sign`。它们分别组合 SleepableBehavior、OpenableBehavior、InspectableBehavior；行为规则在 Behavior，开启状态在 FurnitureState，视觉与行为配置在 FurnitureDefinition。

所有家具实例共用 FurniturePresentation。Game 当前仍临时初始化三件 Furniture Entity / State；Location 加载后只创建并绑定 Presentation。离开 Location 会释放 Presentation，但 Furniture 和 State 继续存在，重新进入时恢复箱子的开启视觉。

## Action 调用链

```text
PlayerController
→ InteractionTargetSelector 命中 FurniturePresentation
→ 返回逻辑 Furniture Entity
→ WorldAction(actor: Actor, target: Entity)
→ ActionSpatialRule 使用 EntityState
→ Furniture 委派对应 Behavior
→ 更新 FurnitureState / WorldTimeState
→ FurniturePresentation 刷新表现
```

## 验证

- ActorDefinitionLoader：53 项检查通过；
- FurnitureDefinitionLoader：22 项检查通过；
- EntityRegistry：16 项检查通过；
- V7.4 运行链：107 项检查通过；
- Player 移动、四向视觉、碰撞、Camera、交互与 Location 切换通过；
- sleep、open、close、inspect 结果保持；
- Furniture Entity / State 跨 Location 卸载持续存在，重新进入后 Presentation 重新绑定并恢复箱子开启状态；
- Martha ActorDefinition 仍可正常加载；
- 当前代码、数据、Scene 与测试中不再引用旧 Character / WorldObject 抽象。

历史开发日志保留当时版本使用的旧术语，用于记录迁移过程，不是当前架构定义。
