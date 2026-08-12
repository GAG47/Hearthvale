# V7.3 Character 表现分离与四向静态视觉开发日志

日期：2026-08-13

## 本次目标

V7.3 整理 Character、CharacterRegistry、CharacterPresentation 与玩家控制的职责，并把角色视觉收敛为由 CharacterState.facing 驱动的四向静态图片。本版本没有引入行走动画、AnimatedSprite2D、SpriteFrames 或多帧动画系统。

## 玩家控制与运行初始化

原 Player Node 中的输入、移动和交互职责迁移到 PlayerController。CharacterRegistry 收缩为登记与查询逻辑 Character 的集合，不再负责创建预设 CharacterDefinition、CharacterState 或玩家表现；Game 负责当前临时世界内容的初始化，并在 Location 加载时创建和绑定表现。

PlayerController 继续处理四方向输入、禁止对角移动、碰撞、Camera 跟随、Action 与 Location 切换。Camera 位置同步收敛到物理帧，项目启用物理插值，并为 Camera 配置物理帧更新与平滑设置，解决角色移动时明显抽动的问题。

## 通用 CharacterPresentation

Player 与 Martha 改为共用 CharacterPresentation Scene，不再各自使用 Player Scene 或 VillagerPresentation 子类。CharacterPresentation 只承担当前 Scene 中的 Sprite、碰撞、位置同步和 Character 绑定；逻辑身份、Location、位置与朝向仍由 Character / CharacterState 持续保存。

CharacterDefinition 的单一表现 Scene 引用先收敛为静态视觉资源，最终改为必需的四向 `visuals`：

- `up`；
- `down`；
- `left`；
- `right`。

Loader 要求四个方向同时存在、为非空 String、资源存在且可加载为 Texture2D，不使用其他方向自动补全。CharacterPresentation 根据 CharacterState.facing 选择对应 Texture；朝向变化时立即刷新，Location 切换后由同一 State 恢复正确方向。临时 Player 与 Martha 素材分别提供四个方向的静态 SVG。

四向图片已经直接表达 facing，因此中间版本用于调试方向的 DirectionIndicator 在最终结构中删除。

## 验证

测试覆盖 CharacterDefinitionLoader、CharacterRegistry 与 V7.3 运行链，包括四向资源校验、Player / Martha 数据、State 绑定、位置和朝向同步、Location 切换及 Presentation 重建。最终确认 Player 显示与四向切换正常，Martha 数据可加载，移动、Camera、碰撞和 Action 保持原有行为。

V7.3 仍使用当时的 Character 术语；V7.4 才把 Character 与 WorldObject 迁移到统一 Entity 架构。
