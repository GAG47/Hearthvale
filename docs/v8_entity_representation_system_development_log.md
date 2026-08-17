# V8：Entity Representation System

日期：2026-08-13

## 本次目标

V8 正式建立 `Entity → Representation Factory → Representation` 的统一桥梁。Entity 继续表达独立于 SceneTree 的逻辑身份与状态；Representation 是 Entity 在当前加载 Location Scene 中可创建、销毁和重建的临时空间表现。依赖只从 Representation 层指向 Entity，权威事实仍只属于 EntityState 与 WorldState。

本版本不修改 Player、Furniture、WorldTime 的临时初始化来源，不增加新 Entity 类型、AI、存档或完整 Game 生命周期系统。

## 命名迁移

旧 Actor / Furniture 表现类已直接迁移为 ActorRepresentation 与 FurnitureRepresentation，包括 `class_name`、脚本和场景文件名、场景根节点、变量、函数、PlayerController、GridScene、InteractionTargetSelector、测试与当前架构文档。没有保留 alias、wrapper 或 deprecated 兼容层。

ActorRepresentation 保持 CharacterBody2D，FurnitureRepresentation 保持 Node2D。系统没有建立公共 Representation Node 父类；两者通过 `get_entity()` 共同约定返回绑定的逻辑 Entity。

## Factory 与 Registry

`EntityRepresentationFactory` 是 RefCounted 抽象，接口为：

```text
supports(entity: Entity) -> bool
prepare(entity: Entity, target_location, target_local_position: Vector2) -> Node
```

ActorRepresentationFactory 与 FurnitureRepresentationFactory 分别持有具体 Representation Scene，完成实例化、类型确认并调用对应准备逻辑。Actor Factory 负责四向视觉、碰撞、目标 Location 与位置；Furniture Factory 负责当前状态视觉、占位阻挡、目标 Location 与位置。准备成功返回已完成验证的 Node，失败释放临时 Node 并返回 `null`。

`EntityRepresentationRegistry` 只提供 Factory 注册和唯一匹配。它检查全部已注册 Factory：零匹配和多匹配都会明确报错并返回 `null`，恰好一个匹配才返回该 Factory，不存在注册顺序优先级。`create_default()` 在 Representation 子系统内部注册 Actor 与 Furniture Factory；Game 只取得默认 Registry，不知道具体 Factory 或 Representation Scene。

## 与 Location Prepare → Commit 对接

Game 的 Actor / Furniture 创建分支、Representation PackedScene 常量和具体 prepare helper 已删除。Location Prepare 对每个目标 Entity 请求 Registry，取得唯一 Factory 并调用 `prepare()`；任何 Entity 没有唯一 Factory 都使整个 Prepare 失败，临时目标树被释放，旧 Location、WorldState、ActorState 和 PlayerController 保持不变。

Commit 仍只消费 Prepare 已完成的 Location 与 Representation，正式迁移 ActorState、激活目标树、换绑 PlayerController、更新 current_location 并释放旧 Location。它不重新搜索 Factory、加载 Representation Scene、验证视觉或创建碰撞，V7.5 的失败安全边界保持不变。

InteractionTargetSelector 继续使用 Scene 空间索引，但从 ActorRepresentation / FurnitureRepresentation 的 `get_entity()` 取得逻辑对象。WorldAction 只接收 Actor 与 Entity，不依赖 Representation。

## 验证

- V8 Entity Representation System 专项：41 项检查通过；
- V7.4.1 完整运行链：113 项检查通过；
- V7.5 Location Prepare → Commit：58 项检查通过；
- Factory 的 Actor / Furniture 支持矩阵及具体准备通过；
- Registry 注册、零匹配、唯一匹配和多匹配通过；
- 缺失 Factory 时 Location Prepare 失败，WorldState、current_location、ActorState 与 PlayerController 均保持不变；
- Player 移动、四向视觉、碰撞、Camera 与 interaction 保持正常；
- Furniture sleep、open、close、inspect 及 BehaviorState 往返恢复保持正常；
- 静态边界检查确认 Game 不再以 Actor / Furniture 类型分支创建 Representation，也不引用具体 Factory 或 Representation Scene；
- Entity、Actor、Furniture、EntityRegistry、WorldState 和 WorldAction 不依赖 Representation。
