# V2 世界对象与交互基础开发日志

日期：2026-08-09

## 本次目标

在现有三个 Location 和 V1 空间系统之上，建立有稳定身份、空间占位、碰撞、状态与行为能力的 WorldObject，并让玩家能够通过统一交互输入对一个明确目标提出行为，获得经过规则判断的正式结果。

本次没有实现箱子库存、睡眠与时间推进、完整物品系统、NPC、完整 World State 或跨场景持久化。

## 地图与世界对象边界

现有 TileMapLayer / TileSet 继续负责地面、墙体、道路、建筑边界和门等固定地图结构。需要独立身份、状态或行为的内容由独立 WorldObject 场景表达，不作为 TileMap 瓦片状态处理。

WorldObject 当前记录：

- 稳定 `object_id`；
- 当前 Scene 上下文中的所属 Location；
- 32×32 px 格子中的锚点和占用格数；
- 是否阻挡移动；
- 当前可提供的零个、一个或多个行为。

对象节点进入场景后根据锚点和占用格计算实际中心位置，并按照占位设置阻挡碰撞。WorldObject 本身不等同于可交互对象。

## 酒馆中的实际对象

| 对象 | 稳定 ID | 格子占位 | 当前行为与状态 |
| --- | --- | --- | --- |
| 储物箱 Chest | `tavern.storage_chest` | 1×1 | `open` / `close`；closed 与 open 两种状态及不同贴图 |
| 告示牌 Sign | `tavern.notice_board` | 1×1 | `inspect`；返回“今日麦酒三铜币。” |
| 床 Bed | `tavern.guest_bed` | 1×2 | 提供 `sleep`，当前规则以“当前还不能睡觉。”拒绝 |

三者都使用 Sprite2D 和占位 SVG 表现，使用 StaticBody2D、CollisionShape2D 与占用格对应地阻挡玩家。世界对象没有使用 `_draw()` 绘制。

## 交互目标选择

项目增加统一的 `interact` Input Action，默认绑定物理 E 键。玩家提出交互意图时，仅检查当前 Location 中的 WorldObject，并根据以下条件选取目标：

1. 对象当前提供至少一个行为；
2. 对象位于玩家当前朝向的前方；
3. 对象处于短距离和有限横向宽度内；
4. 多个候选同时成立时只选择距离最近的一个。

玩家可以连续移动，不需要站在格子中心。对象不各自监听键盘输入。

## Action、Rule 与 Result

当前行为以稳定的行为 ID、Actor 和目标 WorldObject 构成。行为执行先取得明确的规则判断；拒绝时直接返回带原因的 failure，允许时才调用对应执行逻辑并返回 success 或 failure。

Player 不直接修改具体对象状态，也不直接更新结果 UI。它发出行为结果，由游戏表现层在画面下方暂时显示消息。当前行为 ID 为：

- Chest：`open`、`close`；
- Sign：`inspect`；
- Bed：`sleep`。

## 场景生命周期限制

稳定 `object_id` 与当前承载对象的 Scene Node 已明确区分，但还没有实现长期 World State。Location 切换会卸载当前场景并在返回时重新实例化，因此打开箱子后离开酒馆再返回，箱子会恢复 closed。新实例仍使用相同 `object_id`，但当前状态不会跨 Location 重载保留。

本次没有使用全局变量或 SceneTree 补丁绕过这一限制；跨重载状态权威留给后续 World State 的正式设计。

## Godot 实际验证

使用 Godot 4.7.1 对项目进行了编辑器解析、无界面运行检查、脚本化物理检查和 X11 实际渲染画面检查。结果如下：

- 酒馆中的 Chest、Sign、Bed 均能正常加载和显示；
- Chest 首次交互执行 open，贴图改变并显示“箱子打开了。”，再次交互执行 close 并恢复；
- Sign 执行 inspect 并显示“今日麦酒三铜币。”；
- Bed 发起 `sleep` 后由规则拒绝，显示“当前还不能睡觉。”；
- 距离过远或朝向相反时不会误选目标；
- Sign 与 Chest 同处交互范围时只选择更近的 Sign，Chest 不会同时响应；
- 三种对象的碰撞都能阻挡玩家；
- 玩家仍为上下左右连续移动，不产生对角移动，镜头和 TileMapLayer 地图正常；
- 实际控制玩家走入前门、街道酒馆入口、后门和后院入口，四次切换及对应入口位置均正确；
- Location 重载后对象 Node 实例改变、稳定 ID 保持相同，Chest 状态按上述限制重置；
- 运行过程未发现失效节点、脚本解析错误或场景引用错误。
