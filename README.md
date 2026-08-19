# Hearthvale

Hearthvale 是一款中世纪西幻 RPG / Living World 游戏。玩家作为世界中的人物，在小镇、周边野外以及自己经营的酒馆之间生活、行动，并参与一个持续变化的世界。

## 技术栈

- Godot 4.7.1
- GL Compatibility 渲染模式

## 当前状态

当前世界采用 Location-First 数据架构。Project Definition 是 Godot Custom Resource，Actor、Furniture 与 Location Instance 直接持有对应的强类型 `.tres` 引用；State 只保存具体实例的运行事实，Entity 与 Location Instance UUID 继续保持独立身份。LocationDefinition 直接描述 Topology，以及 Ground、Decoration、Structure 三层 Cell Tile Resource 和 Entries / Exits；LocationState 只保存三层 Resource sparse overrides，Entity 归属仍唯一来自 EntityState。Entity Definition 可以通过 UseSlot 与 SlotEntrance 表达各 Action 的局部交互位置，Location 负责转换和验证当前 Location Cell。ActorState 保存已经提交的 logical Cell，ActorDefinition 保存 `move_speed` 等固定定义；独立于 Scene 的 LogicalMovement 通过 AStarGrid2D + Causal-PIBT 推进移动，并保存 tail/head、phase、progress、step duration 与 transient hard occupancy。ActorRepresentation 根据 logical movement progress 在两个 Cell Center 之间进行连续画面插值；PlayerController 只是控制其中一个 Actor。LocationSceneBuilder 从当前 Location 动态生成 LocationScene，再沿用 V8 Factory / Registry 创建 Entity Representations；固定地图 `.tscn` 不是世界真相。Location 切换继续采用失败安全的 Prepare → Commit，Entry 支持按顺序选择多个 arrival Cells，Scene 卸载不影响 Definition Resource、LocationState、Entity、EntityState 或 NPC Movement。

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
- [V8：Entity Representation System](docs/v8_entity_representation_system_development_log.md)
- [V9：Location-First World Data](docs/v9_location_first_world_data_development_log.md)
- [V10：Entity Interaction Space](docs/v10_entity_interaction_space_development_log.md)
- [V11：Logical Actor Movement](docs/v11_logical_actor_movement_development_log.md)
- [V11.3：Location Naming & Responsibility Cleanup](docs/v11_3_location_naming_responsibility_cleanup_development_log.md)
