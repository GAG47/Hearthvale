# V7.4.1：Entity Architecture Cleanup

## EntityRegistry

EntityRegistry 的登记校验只依赖 Entity 共同边界：Entity 非空、EntityState 非空、`entity_id` 是合法 UUID v4，以及 Entity 与 State 的 ID 一致。Registry 不再引用 Actor 或 Furniture，因此新增合法 Entity 子类不需要修改 Registry。

## Actor → Entity Action

Entity 提供最薄的 Action 目标协议：`get_supported_actions()`、`get_primary_action()`、`check_action()`、`apply_action()`，默认明确拒绝不支持的行为。Furniture override 这组协议并继续把具体规则委派给 Behavior。

PlayerController 直接向目标 Entity 请求 primary action；WorldAction 在公共空间规则通过后，直接调用目标 Entity 的 check / apply。两处都不再把目标强转为 Furniture。本轮没有增加 Actor → Actor 的具体行为，Actor 目标使用 Entity 默认拒绝结果。

## BehaviorState

```text
FurnitureState
└─ behavior_states
   └─ openable → OpenableState
                  └─ is_open
```

BehaviorState 是轻量状态基类，OpenableState 保存每个具体 Furniture 实例自己的 `is_open`。FurnitureState 不再直接包含该字段；SleepableBehavior 与 InspectableBehavior 没有独立动态事实，因此没有空 State 类型。

Furniture 创建逻辑 Behavior 时，为 Definition 中的 openable 能力绑定或初始化 OpenableState。WorldState 仍持有同一个 FurnitureState，Location 卸载只释放 Representation；重新进入时同一 Furniture、FurnitureState 和 OpenableState 被重新表现，开启状态不会丢失。

## 通用反馈

Furniture Behavior 不再写死床、箱子或告示牌名称。需要目标名称的通用反馈从 `FurnitureDefinition.display_name` 生成；inspect 内容仍由 Definition 的 Behavior 配置提供。

## 验证

- ActorDefinitionLoader：53 项检查通过；
- FurnitureDefinitionLoader：22 项检查通过；
- EntityRegistry 与通用 Entity Action 协议：22 项检查通过；
- V7.4.1 运行链：113 项检查通过；
- 主场景 headless smoke 正常退出；
- Player 移动、四向视觉、Camera、碰撞和 Interaction 保持正常；
- sleep、open、close、inspect 正常；
- 每个 Furniture 使用独立 OpenableState，开启状态跨 Location 卸载与重载恢复；
- 静态扫描确认 Registry、WorldAction、PlayerController 与 Behavior 中没有本轮禁止的旧依赖。

## 范围

本次只收紧 V7.4 已建立的边界，没有增加新 Behavior、Behavior Factory、Actor 间交互、家具摆放、Location 生命周期或 Game 生命周期系统。
