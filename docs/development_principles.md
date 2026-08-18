# Hearthvale 开发原则

## 1. 从整体设计出发

开发具体系统之前，先考虑它在整个游戏中的职责、与其他系统的关系以及长期位置，不能只围绕眼前的一个玩法作出设计。

整体设计用于明确边界和方向，不意味着要在需求出现前设计全部实现细节。

## 2. 禁止最小闭环污染架构

不以“尽快做出最小可玩闭环”作为架构设计原则。

不能为了尽快拼成“输入 → 玩法 → UI → Demo”，让几个尚未设计清楚的系统互相迁就，也不能让临时演示需求决定长期职责边界。

## 3. 所有开发必须能够真正验证

不能只写抽象架构、后台逻辑和 smoke test，却长期没有真实游戏表现。

进入实际开发的游戏功能应该具有可观察、可操作的验证方式。涉及实际游戏体验的内容，原则上应该能够在 Godot 游戏画面中验证。

自动测试、smoke test、日志和调试输出可以补充验证，但不能长期替代实际游戏验证。

## 4. 验证不决定架构

游戏画面和验证场景用于确认已经设计好的系统是否正常工作。

不能为了方便制作验证场景，反过来把系统设计成只适用于该场景。验证需要暴露真实行为，而不是制造一套与正式系统不同的捷径。

## 5. 不提前制造没有消费者的结构

不要因为“以后可能用到”就提前创建字段、抽象层、Manager、Factory、Compiler、接口或配置体系。

存在真实需求和明确消费者后，再建立相应结构。新增抽象应解决已经出现的问题，而不是只证明某种架构形式完整。

## 6. 当前游戏范围不等于底层架构范围

当前游戏内容主要围绕小镇、周边野外和玩家经营的酒馆展开，但不能因此把底层交易、角色、地点、战斗、物品等系统写成酒馆专用系统。

具体功能应服务当前真实需求，同时避免把内容范围误当作长期能力边界。

## 7. Player 不是独立的世界实体类型

Player is not a separate world entity type.

PlayerController only supplies player control to an Actor.

Persistent state, movement facts, interaction rules and gameplay capabilities remain the same Actor systems used by NPCs.

控制方式、信息来源和决策方式可以不同，但不能因此建立 PlayerDefinition、PlayerState、PlayerMovementState 或 `is_player` 身份字段，也不能产生两套相互矛盾的世界规则。

## 8. Movement 属于 Logical World

Location Logical World 的正式空间单位只有 `Vector2i` Grid Cell。EntityState 只保存 `local_cell`，不能同时保存 pixel `local_position`，也不能从 Representation、Scene transform 或连续 Vector2 反推 Entity 当前 Cell。`Entity.current_cell` 表示已经提交的稳定 Cell，不等于 Actor 在 Movement phase 中的完整 occupancy。

Movement Intent、Grid Pathfinding、Causal-PIBT 协调、Step progress 与 Actor occupancy 都是逻辑世界能力。Player 与 NPC 都必须通过同一个 Logical Movement，以 `contracted → requesting → extended → contracted` 完成一次四向相邻 Cell Move。ActorState.local_cell 在 contracted、requesting 和整个 extended 期间保持 tail，只在 Step 完成时一次性 Commit 为 head。Location Scene 是否加载不能决定 Actor 是否能够移动。

ActorRepresentation 只把 committed Cell 与 Movement tail/head/progress 转换为 Scene `Vector2`：稳定位置使用 Cell Center，extended 使用两个 Cell Center 之间的插值。平滑像素位移是 Representation，不是连续 Logical Position；Representation 不能拥有正式位置权威，也不能在销毁时把旧坐标反写为世界事实。

PlayerController 只提供最新 direction intent，不直接设置 velocity、调用 Scene Physics 移动 Actor 或把 Representation 同步回 State。方向输入必须立即更新普通 Actor facing，再尝试移动；Step 被阻挡时可以不移动，但 facing 仍应改变。NPC 的 target intent 可以使用 AStarGrid2D 产生多个邻格候选；direction intent 只能包含指定邻格与 WAIT，不能由协调器替玩家自动改向。

Hard occupancy 必须与请求意图区分：contracted 占 `{tail}`，requesting 仍只占 `{tail}`，extended 才占 `{tail, head}`。requesting head 不能成为 Location Entry 或其他外部系统的空气墙。

需要 UseSlot 的 Spatial Action 要求 Actor 稳定位于 Slot Cell。contracted 与 requesting 可以继续按 committed tail Cell 验证；extended 必须由 ActionSpatialRule 正式拒绝，不能只在 PlayerController 做特例拦截，也不能读取动画位置判断 Interaction。

Causal-PIBT 核心必须用 original/current priority、parent/children、候选集合 `C_i`、搜索集合 `S_i`、priority inheritance、backtracking 与 request-cycle 检查表达。不能以递归 resolver、VISITING status、assignment snapshot/restore，或 retry/deadlock/corridor 特例替代正式状态模型。高级 deadlock、未来时间 reservation、edge reservation、congestion 与 traffic optimization 扩展不属于 V11.2，不能为了追求“绝对不会卡死”而擅自加入。

## 9. AI 不拥有规则权威

AI 可以创造内容、提出建议和辅助决策，但不能直接确定世界事实。

确定性的世界状态变化仍由游戏规则验证，并由游戏系统执行。AI 输出不能成为绕过正常规则流程的特殊入口。

## 10. 保持实现可理解

优先采用简单、清晰、可追踪的实现，使行为来源、规则判断和状态变化能够被理解和定位。

不要为了形式上的“高级架构”引入不必要的复杂度。只有在复杂度解决了真实问题时，才应承担它带来的维护成本。

## 11. 用继承表达根本差异，用组合表达能力

只有基础结构、生命周期或核心职责真正不同，才建立新的大类或继承层级。同一类实体之间“能做什么”的差异，优先通过数据与组合表达，不要不断建立 MerchantActor、GuardActor、BedFurniture、ChestFurniture 等类型来表示能力差异。

如果一项能力拥有自己的动态状态，该状态也应独立组合，不应持续向公共父级 State 增加能力专属字段。

组合本身也不能成为过度设计的理由。只有真实能力、真实消费者或真实动态状态出现后，才建立对应 Behavior、Component 或 State；不为形式完整预建空组件和无消费者抽象。

## 12. 保持开发日志的历史真实性

旧版本 development log 是对应版本实现状态的历史记录。后续架构变化不能作为重写旧日志的理由；只有发现旧日志本身存在事实错误时才允许修正，并且应明确这是后续修正，而不是静默改写历史。当前架构应记录在 `architecture.md`，当前版本的变化应记录在对应的 development log。
