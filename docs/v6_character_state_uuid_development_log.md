# V6 Character Definition、Character State 与统一实体 UUID 开发日志

日期：2026-08-11

## 本次目标

本次建立角色作为持续世界实体的基础：世界能够在 Character Scene Node 不存在时继续知道角色身份、当前 Location、局部位置和朝向，并能在相应 Location 加载时根据 Definition 与 State 恢复角色表现。同时把现有固定 WorldObject 的永久身份迁移到同一 UUID v4 规则。

本次没有实现日程、Goal、FSM、行为树、Utility AI、LLM 决策、NPC 自动行动、跨 Location 寻路、离屏模拟、旅行时间、关系、知识、记忆、对话、职业、库存扩展、战斗属性、完整 Save / Load 或万能 Entity Registry。

## 统一 UUID v4

新增 `UuidGenerator.generate_v4()`。它使用 16 字节随机数据并设置 RFC 4122 的 version 4 与 variant 位，只负责生成无语义 UUID，不保存、查询或分类实体。独立的 `UuidValidator` 负责格式校验。

预设 Character 与固定 WorldObject 都使用一次生成后永久固定的 UUID v4。ID 不包含名称、类型、Location、职业、用途或生成顺序；Character 继续使用 `character_id`，WorldObject 继续使用 `object_id`，没有因此合并成一种实体或一个全局 Registry。

酒馆中三个固定 WorldObject 已从递增语义 ID 迁移为：

| 对象 | UUID v4 object_id |
| --- | --- |
| Chest | `5543caf7-2a10-4a40-84de-3a39ffdf670e` |
| Sign | `1d67bbf9-edc2-4264-a861-8bd3e3e61e15` |
| Bed | `a6ae5842-8c6d-4df2-9b80-a271b5496716` |

原有 `object_id → WorldObjectState`、固定对象定义冲突检查、Location 内格子索引、交互和 ChestState 持续逻辑保持不变。WorldState 会拒绝非 UUID v4 的 WorldObject ID；没有新增全局 WorldObject Registry。

## CharacterDefinition 与 CharacterState

CharacterDefinition 当前只有三个已有消费者需要的字段：

- `character_id`；
- `display_name`；
- `presentation_ref`。

CharacterState 当前只有四个世界动态事实：

- `character_id`；
- `current_location_id`；
- `local_position`；
- `facing`。

同一 Character 通过相同 UUID 关联两者。Definition 不包含当前 Location、位置或朝向，State 不复制名称和表现引用。角色初始 Location 与位置由独立的初始 CharacterState 数据提供。

WorldState 新增 `character_id → CharacterState` 集合以及通用登记、获取、存在性和遍历接口。CharacterState 因此与 WorldTimeState、WorldObjectState 一样独立于 Location Scene 生命周期，并且不会因角色 Node 释放而消失。

## Character Registry

新增 CharacterRegistry Autoload，作为当前世界中 Character 的领域权威集合。它支持：

- 按 `character_id` 获取 Character；
- 判断 ID 是否存在；
- 稳定遍历所有 Character；
- 按 CharacterState.current_location_id 查询某个 Location 中的 Character。

登记会验证 Definition 与 State 的 UUID 一致、UUID v4 格式、当前 Location 存在以及 presentation_ref 能实例化为 CharacterPresentation，然后把 State 登记到 WorldState。Registry 不管理 WorldObject、Location 或其他实体类型。

当前只有两个用于实际验证的预设角色：玩家位于 Tavern，Martha 位于 Tavern Yard。两者都使用 UUID v4，Definition 与初始 State 明确分开。Martha 只有简单占位表现，没有 AI、日程或自动行为。

## Character 与 Scene 生命周期

原先作为永久角色本体放在 Main Scene 中的 Player Node 已移除。逻辑 Character 现在是 Definition 与 State 的组合，不继承 Node；PlayerCharacter 与 VillagerPresentation 都是加载后才存在的 CharacterPresentation。

Location 加载流程现在是：

```text
加载并验证 Location
  ↓
Character Registry 按 location_id 查询 Character
  ↓
读取 CharacterDefinition.presentation_ref
  ↓
实例化 CharacterPresentation
  ↓
绑定同一逻辑 Character
  ↓
从 CharacterState 恢复 local_position 与 facing
```

玩家移动时持续同步局部位置，朝向直接读写 CharacterState。Location 卸载时，各 CharacterPresentation 再同步当前状态后释放。Location 切换会先把移动角色的 State 更新为目标 Location 和目标 Entry；目标场景随后通过同一查询流程创建新的 PlayerCharacter Node。没有把权威位置、朝向或角色存在性留在 Scene Node 中。

## 主要文件变化

- `scripts/identity/uuid_generator.gd`：UUID v4 生成。
- `scripts/identity/uuid_validator.gd`：UUID v4 格式验证。
- `scripts/characters/character_definition.gd`：静态角色定义。
- `scripts/characters/character_state.gd`：运行时角色世界状态。
- `scripts/characters/character_registry.gd`：Character 权威集合、查询与预设初始化。
- `scripts/character.gd`：改为独立于 Node 的逻辑 Character。
- `scripts/characters/character_presentation.gd`：角色世界实体与当前 Scene Node 的绑定和空间适配。
- `scripts/characters/villager_presentation.gd`、`scenes/characters/villager.tscn`：Martha 的最小占位表现。
- `scripts/player.gd`、`scripts/game.gd`、`scenes/main.tscn`：玩家改由 Location 加载流程创建、恢复和卸载。
- `scripts/world_state/world_state.gd`：纳入 CharacterState，并校验 WorldObject UUID。
- `scripts/actions/action_spatial_rule.gd`、`scripts/interaction_target_selector.gd`：现有空间 Action 继续以逻辑 Character 为 Actor；Presentation 只负责当前场景中的目标选择和状态同步。
- `scenes/tavern.tscn`：迁移三个固定 WorldObject ID。
- `project.godot`：注册 CharacterRegistry Autoload。
- `README.md`、`docs/architecture.md`：更新当前状态和正式架构边界。

## 实际验证

Godot 4.7.1 项目导入与运行通过，未出现脚本解析错误。专项运行验证确认：

1. 连续生成 256 个 UUID 均为合法 UUID v4，彼此不重复；语义 ID 和旧递增 ID 会被拒绝。
2. 玩家与 Martha 的 Definition / State 使用相同 ID 正确关联；Definition 和 State 没有复制对方职责字段。
3. Character Registry 的按 UUID 获取、存在性、稳定遍历和按 Location 查询全部正常。
4. Martha 的 Location 未加载时没有对应 Scene Node，但 Character、Definition 和 CharacterState 仍然存在。
5. Tavern Yard 加载时 Martha 按 presentation_ref 创建，并恢复 State 中的位置与朝向；离开后 Node 释放，修改后的位置与朝向继续保留；再次进入会创建新 Node 并恢复同一状态。
6. 玩家也由 Tavern 加载流程创建；Tavern 与 Town Street 双向切换后是新的 PlayerCharacter Node，但绑定相同 Character 与 CharacterState，并正确恢复目标入口。
7. 三个 WorldObject UUID 合法且互不重复，并与两个 Character UUID 不冲突。
8. 玩家四方向连续移动、禁止对角移动、碰撞、Camera、四条 Location 连接、Entry 落点、Chest / Sign / Bed 交互和空间规则均正常。
9. ChestState 跨 Location Scene 持续；睡眠仍推进到下一天 08:00；WorldTime 跨 Location 切换持续，V3–V5 行为无回归。

V6 到此结束，没有进入后续系统开发。
