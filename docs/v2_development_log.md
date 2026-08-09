# V2 世界对象与交互基础开发日志

首次完成：2026-08-09

结构收尾：2026-08-10

## 本次目标

在现有三个 Location 和 V1 空间系统之上，建立有稳定身份、空间占位、碰撞、状态与行为能力的 WorldObject，并让玩家能够通过统一交互输入对一个明确目标提出行为，获得经过规则判断的正式结果。

本次没有实现箱子库存、睡眠与时间推进、完整物品系统、NPC、完整 World State 或跨场景持久化。

## 地图与世界对象边界

现有 TileMapLayer / TileSet 继续负责地面、墙体、道路、建筑边界和门等固定地图结构。需要独立身份、状态或行为的内容由独立 WorldObject 场景表达，不作为 TileMap 瓦片状态处理。

WorldObject 已使用 Godot 4.7.1 的 `@abstract` 声明为抽象基础，不能直接作为具体对象实例化。它当前记录：

- 稳定 `object_id`；
- 当前 Scene 上下文中的所属 Location；
- 32×32 px 格子中的锚点和占用格数；
- 是否阻挡移动；
- 当前可提供的零个、一个或多个行为。

对象节点进入场景后根据锚点和占用格计算实际中心位置，按照占位设置阻挡碰撞，并把全部占用格登记到所属 GridScene；离开场景时从索引注销。WorldObject 本身不等同于可交互对象，`get_supported_actions()` 只表达对象支持的行为，不表示行为已经通过规则。

## Character 与 Location 格子索引

增加抽象 Character，PlayerCharacter 改为继承该基础。Character 当前只承担：

- `current_location`；
- 连续世界位置；
- 从连续位置换算出的 `current_cell`；
- 上、下、左、右 `facing` 及 facing 相邻格。

玩家移动、碰撞、Camera 和输入行为保持原样。Character 没有增加背包、属性、AI、日程或战斗数据。

每个 GridScene 维护 `Vector2i → Array[WorldObject]` 的局部索引。WorldObject 的每一个占用格都登记同一对象引用，因此 1×2 Bed 可以从两个格子查询到。该索引随 Location 场景建立和销毁，只用于当前空间查询，不是 World State 持久化或全局对象注册中心。

## 酒馆中的实际对象

| 对象 | 稳定 ID | 格子占位 | 当前行为与状态 |
| --- | --- | --- | --- |
| 储物箱 Chest | `tavern.storage_chest` | 1×1 | `open` / `close`；closed 与 open 两种状态及不同贴图 |
| 告示牌 Sign | `tavern.notice_board` | 1×1 | `inspect`；返回“今日麦酒三铜币。” |
| 床 Bed | `tavern.guest_bed` | 1×2 | 提供 `sleep`，当前规则以“当前还不能睡觉。”拒绝 |

三者都使用 Sprite2D 和占位 SVG 表现，使用 StaticBody2D、CollisionShape2D 与占用格对应地阻挡玩家。世界对象没有使用 `_draw()` 绘制。

## 交互目标选择

项目使用统一的 `interact` Input Action，默认绑定物理 E 键。玩家提出交互意图时，Selector 直接向 `actor.current_location` 的格子索引查询：

1. 优先查询 facing 方向的相邻格；
2. 前方格没有候选时查询 Character 当前格；
3. 只考虑当前支持至少一个行为的对象；
4. 同格多个候选按稳定 `object_id` 排序，只选择一个。

玩家可以连续移动，不需要站在格子中心。Selector 不再遍历 `world_objects` group，旧 group 及像素距离、横向宽度筛选已经删除。对象不各自监听键盘输入。

## Action、Rule 与 Result

当前行为以稳定的行为 ID、Character 和目标 WorldObject 构成。WorldAction 执行时首先调用公共 `ActionSpatialRule`：

1. 验证 actor 和 target 有效；
2. 验证两者属于同一个 Location；
3. 验证目标占据 actor 当前格或 facing 相邻格；
4. 通过后再调用目标自身的 `check_action()`；
5. 全部规则通过后才调用 `apply_action()`。

空间规则拒绝会返回正式 failure、可读消息和 `target_not_in_same_location`、`target_out_of_interaction_space` 等失败代码。Selector 负责“玩家想选谁”，ActionSpatialRule 负责“已经形成的 Action 在空间上是否合法”。

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
- WorldObject 和 Character 均无法被直接构造为具体实例；
- Character 能正确提供 Location、连续位置、当前格和 facing 相邻格；
- Chest、Sign 及 Bed 的所有占用格均正确登记，Bed 可从两个占用格查询；
- 对象离开场景时会从 Location 索引注销，Location 重载会重新建立索引；
- Selector 能按前方格、当前格顺序选择对象，同格多对象只返回稳定排序后的一个；
- 距离较远的 SceneTree 对象不会因存在于场景中而被选中；
- 绕过 Selector 创建的跨 Location 和超出交互格 Action 均返回明确 failure；
- 非法空间 Action 不会执行 Chest 状态修改；
- 三种对象的碰撞都能阻挡玩家；
- 玩家仍为上下左右连续移动，不产生对角移动，镜头和 TileMapLayer 地图正常；
- 实际控制玩家走入前门、街道酒馆入口、后门和后院入口，四次切换及对应入口位置均正确；
- Location 重载后对象 Node 实例改变、稳定 ID 保持相同，Chest 状态按上述限制重置；
- 运行过程未发现失效节点、脚本解析错误或场景引用错误。
