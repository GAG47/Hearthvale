# V9.2：Static Definition Resource + Entity Authoring

日期：2026-08-14

## 本次目标

V9.2 将 Actor / Furniture 静态 Definition 从自定义 JSON 迁移为 Godot Custom Resource，并把固定内容链路统一为：

```text
Definition .tres（ResourceUID）
→ Scene Placement 强类型引用
→ Baking definition_uid
→ Initial Entity Data
→ EntityFactory 按 UID 加载 Resource
→ Entity + EntityState
→ V8 Representation
```

## Definition Resource

ActorDefinition 与 FurnitureDefinition 现在都继承 Resource，不再保存自定义 `definition_id`。Player、Martha、床、储物箱和告示牌已经迁移为 `.tres`，其静态资产身份由文件内固定的 Godot ResourceUID 提供。

ActorDefinition 使用 String display_name 与四个强类型 Texture2D 方向视觉。FurnitureDefinition 使用 String display_name、Texture2D visual、Vector2i occupied_cells、bool blocks_movement 和现有 Behavior Dictionary；储物箱开启视觉同样是 Texture2D。Furniture 的 Behavior / BehaviorState 运行规则没有改变。

## Authoring Preview

ActorPlacement 与 FurniturePlacement 直接导出强类型 Definition Resource，不再保存路径字符串。Actor Preview 根据 initial_facing 绘制同一 ActorDefinition 的方向视觉；Furniture Preview 绘制同一 FurnitureDefinition 的视觉及按运行时格子规则计算的 occupied_cells。

Definition 或 facing 属性变化会立即 queue_redraw 并更新 Configuration Warning。Actor 缺少 Definition 或当前 facing 视觉、Furniture 缺少 Definition / visual 或 occupied_cells 非法时，Scene Tree 会显示原生配置警告。Preview 不创建 Entity、State、碰撞或 Representation，正常 Location 激活仍会移除 Placement。

## Baking 与运行时

ActorBaker / FurnitureBaker 从 Placement.definition 的 resource_path 查询 ResourceUID，并只把 `definition_uid` 写入 initial_entities.json。输出仍按 Location 与 Scene 顺序保持稳定，失败时不覆盖有效文件。

ActorEntityFactory / FurnitureEntityFactory 直接通过 uid:// 引用加载 Resource，并验证具体 Definition 类型及静态配置，然后生成独立 Entity UUID 与 State。Editor Preview 与 Runtime Representation 读取同一 Definition Texture2D，因此不再存在 JSON 视觉路径到 Texture2D 的第二套转换。

## 清理

旧 Actor / Furniture Definition JSON、ActorDefinitionLoader、FurnitureDefinitionLoader、JSON 校验 fixtures 和专用 Loader 测试已经移除。Initial Entity Data、Placement、Baker、Factory 与游戏初始化中不再使用 `definition_path` 或自定义 `definition_id`。

## 数据边界

- 静态项目内容：Godot Resource + ResourceUID；
- 运行世界事实：EntityState、BehaviorState 以及未来存档中的 Memory、Relationship、World Event、AI Generated World Data；
- AI 交换边界：经过选择、验证和模型转换的 JSON。

V9.2 只记录 AI 数据边界，没有实现 AI、Memory、Relationship 或生成世界系统。

## 验证

- Godot 4.7.1 下 V7.4、V7.4.1、V7.5、V8、V9、V9.1 与 V9.2 七组回归共 456 项检查通过；
- 五份 Definition `.tres` 均按强类型正常加载，固定 ResourceUID 可解析；
- Placement Resource 引用、Actor facing Preview、Furniture visual / occupied_cells Preview 和 Configuration Warning 通过；
- Baker 输出 definition_uid，Factory 按 UID 加载正确类型并生成独立 entity_id；
- Resource 移动后更新 UID 映射，同一 ResourceUID 仍可加载；
- 连续两次正式 Baking 产物哈希一致，失败 CLI 返回 1，主场景 headless smoke 返回 0；
- 床、储物箱、告示牌完整 Placement → Baking → Entity → Representation 链保持；
- sleep、open / close、inspect、玩家移动、四向视觉、碰撞、交互与 Location 往返回归保持。
