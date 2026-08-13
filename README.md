# Hearthvale

Hearthvale 是一款中世纪西幻 RPG / Living World 游戏。玩家作为世界中的人物，在小镇、周边野外以及自己经营的酒馆之间生活、行动，并参与一个持续变化的世界。

## 技术栈

- Godot 4.7.1
- GL Compatibility 渲染模式

## 当前状态

世界与空间、静态 Location Graph、统一 Entity、运行时 World State、交互行为和世界时间已经建立。所有 Entity 都拥有永久 UUID v4 和独立 EntityState；当前实现的大类是 Actor 与 Furniture，由 EntityRegistry 统一查询。Godot Scene 中只创建绑定逻辑实体的 ActorPresentation / FurniturePresentation。ActorDefinition 保留四向静态视觉，FurnitureDefinition 通过数据组合 Sleepable、Openable、Inspectable 行为。Location 切换采用 Prepare → Commit：目标 Scene、Entry 与 Presentation 全部准备成功后才迁移 State 并替换当前场景；准备失败不会破坏旧 Location 或控制关系。Location 卸载只释放 Presentation，Entity 与 State 会持续存在并在重新进入时恢复。当前工程可以直接运行，移动、四向视觉、碰撞、Camera、地点切换、家具交互、储物箱状态持续和睡眠推进时间均保持正常。

## 目录

```text
assets/   美术、音频等游戏资源
data/     游戏内容数据
docs/     游戏设计、软件架构和开发原则文档
scenes/   Godot 场景
scripts/  游戏脚本
```

这些目录只表示当前必要的顶层分类。具体子目录将在出现真实内容和需求后再建立。

## 打开项目

使用 Godot 4.7.1 导入或打开根目录下的 `project.godot`，然后运行项目。

使用 `WASD` 或方向键移动玩家；走入场景边缘的门口即可进入相连地点。面对附近的家具按 `E` 进行交互。

## 文档

- [游戏设计](docs/design.md)
- [软件架构](docs/architecture.md)
- [开发原则](docs/development_principles.md)
- [V1：世界与空间基础](docs/v1_world_space_foundation_development_log.md)
- [V2：世界对象与交互基础](docs/v2_world_object_interaction_development_log.md)
- [V3：运行时 World State](docs/v3_runtime_world_state_development_log.md)
- [V4：世界时间与日历](docs/v4_world_time_calendar_development_log.md)
- [V5：World Definition 与 Location Graph](docs/v5_world_definition_location_graph_development_log.md)
- [V6：Character State 与统一 UUID](docs/v6_character_state_uuid_development_log.md)
- [V7.1：脚本领域目录整理](docs/v7_1_script_directory_cleanup_development_log.md)
- [V7.2：CharacterDefinition JSON 数据化](docs/v7_2_character_definition_json_development_log.md)
- [V7.3：Character 表现分离与四向静态视觉](docs/v7_3_character_presentation_four_direction_visuals_development_log.md)
- [V7.4：统一 Entity 架构](docs/v7_4_unified_entity_architecture_development_log.md)
- [V7.4.1：Entity 架构清理](docs/v7_4_1_entity_architecture_cleanup_development_log.md)
- [V7.5：Location Prepare → Commit 生命周期](docs/v7_5_location_prepare_commit_development_log.md)
