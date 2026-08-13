# V7.5 Location Prepare → Commit 生命周期开发日志

日期：2026-08-13

## 本次目标

V7.5 单独修正 Location 切换的事务边界。目标 Scene、Entry 和 Presentation 必须在正式世界改变前完成准备；准备失败时，旧 Location、WorldState、ActorState 和 PlayerController 保持原状。

本版本不整理 New Game / Load Game 初始化，不迁移 Game 生命周期，不创建 Location Manager，也不增加 Entity 类型或玩法系统。

## 原切换风险

原流程会在目标 Presentation 完成资源和结构检查之前，先释放当前玩家表现、卸载旧 Location，并把 ActorState 迁移到目标 Location。之后 Actor 或 Furniture 的视觉加载、节点结构、bind 或受控玩家表现检查一旦失败，就可能留下已经改变的 WorldState 与未完成的新场景。

## Prepare

Game 中的现有 Location 切换入口直接迁移为单一 Prepare → Commit 流程。Prepare 当前负责：

- 查询目标 LocationDefinition；
- 加载和实例化目标 Scene，并确认根节点是 GridScene；
- 按请求的 `location_id` 验证 Scene 身份、来源、Entry 和出口；
- 查找目标 Entry 并计算迁移 Actor 的 spawn position；
- 查询目标 Location 中已有的 Entity，并加入本次迁移的受控 Actor；
- 实例化和准备所需的 ActorPresentation / FurniturePresentation；
- 验证受控 Actor 对应的 Presentation 唯一且可由 PlayerController 接管；
- 预检目标 Location 可以登记为活动场景。

Prepare 创建的目标 Location 和 Presentation 尚未加入 SceneTree。该阶段不修改 EntityState，不触碰 WorldState 中的正式事实，不释放旧 Player Presentation，也不改变当前控制对象或 `current_location`。任一步失败都会立即释放临时目标树，不执行 rollback。

## Presentation 准备

ActorPresentation 原来的 bind 收敛为 `prepare_actor()`：它使用明确传入的目标位置，不再要求 ActorState 已经提前迁移到目标 Location，并在准备时验证 Definition ID、Sprite2D、碰撞 Shape 和四向 Texture2D。

FurniturePresentation 同样改为 `prepare_furniture()`，在进入 SceneTree 前验证 FurnitureDefinition / FurnitureState、Location 归属、占位尺寸、Sprite2D、阻挡碰撞结构以及当前状态对应的 Texture2D。资源加载和结构失败因此都发生在正式 State mutation 之前。

GridScene 保存一次性准备标记。Prepare 预先完成 WorldDefinition 和活动 Location 登记条件检查；Commit 加入 SceneTree 时只正式登记已经准备的 Location，不重复业务验证。PlayerController 增加无状态同步的准备后换绑入口，避免旧 ActorPresentation 在 ActorState 已迁移后再次把旧 Location 写回 State。

## Commit

只有 Prepare 返回完整结果后才执行 Commit：

1. 同步旧 ActorPresentation 的最终位置并结束其 Location 同步；
2. 修改迁移 ActorState 的 `current_location_id` 与 `local_position`，保留 facing；
3. 把已经准备好的目标 Location 与 Presentation 加入 SceneTree；
4. PlayerController 换绑准备好的 ActorPresentation；
5. 更新 `current_location`、Camera 边界和 Location HUD；
6. 从 SceneTree 移除并释放旧 Location。

Commit 不再加载 Scene、视觉资源，不查找 Entry，也不验证 Presentation 节点结构。Location 往返只重建 Presentation；Entity、ActorState、FurnitureState 和 OpenableState 均沿用原对象。

## 验证

新增 V7.5 专项测试，覆盖：

- 目标 LocationDefinition 不存在；
- 目标 Scene 无法加载；
- Scene 根节点不是 GridScene；
- Scene `location_id` 与请求 Definition 不一致；
- 目标 Entry 不存在；
- ActorPresentation 四向视觉无法准备；
- FurniturePresentation 当前视觉无法准备；
- Prepare 成功后的双向 Commit；
- Prepare 失败后旧 Location 仍可移动；
- 成功换绑后的移动、Camera 与四向视觉；
- 打开的 Chest 跨 Location 往返后仍持有同一 FurnitureState / OpenableState，并恢复开启视觉。

专项测试共 58 项检查通过；原 V7.4.1 运行链 113 项检查继续通过。
