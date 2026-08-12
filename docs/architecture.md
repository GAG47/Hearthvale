# Hearthvale 软件架构

## 文档目的

本文以概念级职责领域描述 Hearthvale 软件架构，明确不同职责之间的边界以及世界事实如何产生和改变。

这里的职责领域不是代码模块设计，不对应固定的 Manager、目录、基类、接口或数据格式。实际代码结构只在具体需求出现后决定。

## 职责领域

| 职责领域 | 负责 | 不负责 |
| --- | --- | --- |
| World State | 记录世界中已经成立的事实和当前状态 | 判断行为是否合法、决定角色意图、生成表现内容 |
| World Rules | 判断行为是否合法，并确定行为产生的游戏规则结果 | 采集输入、呈现画面、用开放性内容替代确定性规则 |
| Actions / Interactions | 表达角色对世界采取的行动与交互意图 | 自行判定是否合法、绕过规则直接改变世界事实 |
| Actors | 表达世界中的行动主体，包括玩家和 NPC | 因主体身份不同而擅自改写世界规则、直接宣布行动结果成立 |
| World Simulation | 推进时间，驱动并组织非玩家直接触发的世界变化 | 代替所有游戏规则、任意写入未经验证的世界结果、承担画面表现 |
| Content / AI | 提供开放性、语义性、创造性内容与决策建议 | 拥有规则权威、直接确定或修改世界事实 |
| Presentation | 承担 Godot 中玩家实际看到和操作的场景、画面、UI、输入及其他表现 | 成为世界事实的唯一来源、在表现层自行决定游戏规则结果 |

## 领域之间的基本关系

玩家、NPC 和世界模拟都可能成为世界变化的来源，但它们提出的意图或变化必须经过游戏规则处理，才能成为世界事实。

典型的概念关系是：

```text
变化来源
  ├─ 玩家通过 Presentation 表达操作意图
  ├─ NPC 作为 Actor 作出行动决定
  ├─ World Simulation 推动时间与世界变化
  └─ Content / AI 提供内容或决策建议
          ↓
Actions / Interactions 表达将要发生的行为
          ↓
World Rules 验证并确定规则结果
          ↓
游戏系统执行已确认的结果
          ↓
World State 记录新的世界事实
          ↓
Presentation 呈现世界状态与结果
```

这是一条职责关系，不是对调用顺序、代码依赖或 API 形式的预先规定。

## 空间关系

当前空间采用世界层与场景层两级关系。

世界层由世界节点（Location）及节点间的直接连接组成。一个节点表示一个可以进入、活动和离开的地点；室内与室外节点遵循同一种空间关系，不建立两套地点体系。当前不增加 Region、国家或大陆等上层结构。

场景层把一个世界节点表现为 2D 格子场景。格子是场景结构的最小单位，用于组织地面、建筑、障碍和出口，但不是角色移动的离散步长。角色在格子构成的空间中连续移动，并由碰撞限制可通行范围。

一个节点连接在概念上包含两个必要信息：目标节点，以及进入目标节点时对应的位置。连接是有向的；两个地点之间的双向通行由两条边分别表达，不从其中一条自动推断另一条。连接本身不负责旅行时间、路径搜索或更大范围的地图模拟。

## World Definition 与 Location Graph

WorldDefinition 是当前静态世界结构的统一来源，与保存运行时变化事实的 WorldState 分离。它持有全世界的 LocationDefinition 目录，因此即使对应 Location Scene 没有实例化，系统仍可以查询该地点及其直接连接。

每个 LocationDefinition 当前只包含已经有消费者的信息：

- 稳定 `location_id`；
- 正常可读的 `display_name`；
- 承载该地点的 `scene_path`；
- 从该地点出发的 `outgoing_edges`。

Location 是有向图节点，每个 LocationDefinition 管理自己的出边。每条边以仅在所属 Location 内唯一的 `edge_key` 识别，并只保存 `to_location` 与 `to_entry`。边不重复保存 `from_location`，也不预先包含旅行分钟、距离、成本或动态道路状态。

当前三个节点与四条有向边是：

```text
town_street --tavern_door--> tavern --back_door--> tavern_yard
town_street <--front_door--- tavern <--tavern_door-- tavern_yard
```

GridScene 继续声明自己的 `location_id` 并负责具体格子空间、入口坐标和出口触发位置。LocationEntry 以稳定 `entry_id` 标识场景内落点；LocationExit 只保存 `edge_key`，不保存目标 Scene 路径或目标 Entry。地点显示名与 Scene 映射来自 LocationDefinition，不在每个出口中重复。

玩家触发出口后的基础流程是：

```text
当前 GridScene.location_id + LocationExit.edge_key
  ↓
WorldDefinition 查询有向边
  ↓
取得 to_location + to_entry
  ↓
WorldDefinition 查询目标 scene_path
  ↓
实例化并验证目标 GridScene.location_id
  ↓
按 entry_id 定位目标 LocationEntry
  ↓
卸载当前 Location，进入目标 Location 的实际落点
```

目标 Scene 会在当前 Location 卸载前完成身份、出口和目标 Entry 验证，错误定义不会用半完成的切换替换当前场景。WorldDefinition 初始化校验 Location ID、Scene 资源、局部 edge key、目标 Location 和非空 Entry 标识，并加载全部 Location Scene 做静态图与实际场景的一致性验证。Scene 实例化后双向检查 LocationExit 与 outgoing edge：Scene 中每个 Exit 必须引用已定义边，Definition 中每条边也必须有实际 Exit；同时检查 Scene 身份、Scene 来源、Entry 唯一性，以及每条边的 `to_entry` 在目标 Location Scene 中真实存在。错误信息携带相应的 Location、edge、目标 Location 和 Entry，便于定位静态世界定义。

Location Graph 当前只表达静态空间拓扑。NPC 路线、日程、离屏模拟、旅行时间、距离、道路封锁、天气影响、事件改路和世界地图 UI 尚未实现；未来系统可以查询该图，但不应把这些未确定职责提前塞入边定义。

## 地图结构与世界对象

Location 内的地图结构与世界对象表达不同的事实。

TileMapLayer / TileSet 负责描述“这里是什么空间”，包括地面、墙体、道路和建筑边界等固定地图结构。抽象 WorldObject 负责定义“这个空间中的东西为什么属于世界对象”：具体世界对象能够被稳定引用、具有自身空间占位，并可能拥有状态或参与行为。需要独立身份、状态或行为的内容不应仅作为地图瓦片存在。

当前 WorldObject 的共同职责是：

- 通过创建后永久不变的 UUID v4 `object_id` 表达对象身份；
- 明确解析自己所属的 Location；
- 按 Location 的 32×32 px 格子记录锚点和一个或多个占用格；
- 明确是否阻挡移动，并让阻挡碰撞与空间占位一致；
- 提供零个、一个或多个当前行为。

WorldObject 是抽象基础，不能作为普通具体对象实例化。世界对象不等于可交互对象；成为世界对象不以能够响应玩家交互为前提，交互只是对象可能提供的一种能力。`get_supported_actions()` 表达对象支持哪些行为，不表示这些行为已经通过全部规则并一定能够成功。只有在多类对象已经出现真实共同规则时，才增加中间分类，不因名称相似预建完整对象分类树。

每个 GridScene / Location 维护自己的 WorldObject 格子索引。WorldObject 进入 Location 时把全部占用格登记到该索引，离开场景时注销；多格对象会在每个占用格中指向同一个对象实例。索引服务当前场景中的局部空间查询，不是 World State、对象注册中心或跨场景持久化机制。

`object_id` 与承载对象的 Godot Scene Node 不是同一个概念。前者用于稳定引用世界中的对象，后者是当前 Location 场景生命周期内的运行实例。需要跨场景重载成立的动态事实由运行时 WorldState 持有，不把某次实例化得到的 Node 当作永久世界事实。

## Location、Scene 与运行时 World State

Scene、Location 与 World State 表达不同职责：

- Location 是世界中的逻辑地点，以稳定 `location_id` 识别，并作为空间归属、格子索引和局部查询边界；
- Godot Scene 是该 Location 当前被加载后承担显示、碰撞、交互和场景行为的运行时表现；
- World State 是独立于 Location Scene 生命周期持续存在的动态世界事实。

世界身份使用稳定逻辑 ID。Location 作为静态世界图节点，继续使用明确的 `location_id`；Character 与 WorldObject 作为持续世界实体，分别使用 UUID v4 `character_id` 和 `object_id`。Location 的 `.tscn` 路径由 WorldDefinition 统一关联并用于加载场景，同时可用于开发期定义诊断；它不作为 World State 的事实键或世界身份。

实体 UUID 是纯粹、全世界唯一的永久身份，不编码名称、类型、Location、职业、用途、生成顺序或当前状态。预设实体和以后运行时创建的实体遵循同一 UUID v4 规则：创建时生成一次，此后不变；实体真正删除后旧 UUID 不用于代表另一个新实体。UUID Generator 只生成 UUID，不保存或查询实体，也不判断实体类型；UUID 格式验证是独立职责。Character 与 WorldObject 仍由各自的领域结构管理，不建立万能的全局 Entity Registry。

Definition 与 World State 也保持分离。当前固定对象的 Definition 由场景和对象配置描述类型、稳定 ID、独立的 `initial_location_id`、初始格子位置、占位、阻挡、初始状态及静态表现；World State 只保存运行过程中已经变化、并且在 Scene 卸载后仍需成立的事实。TileMap、碰撞形状、Sprite 和完整 SceneTree 不复制到 World State。

当前运行时 WorldState 是一个随本次游戏运行周期持续存在的 Autoload，也是跨 Scene 动态事实的权威。对象级事实仍通过通用的 `get_object_state(object_id)`、`register_object_state(object_id, state)` 和状态存在性查询访问；WorldState 不理解 Chest、Bed、Sign 等业务对象类型。具体 WorldObject 负责创建、校验和解释自己的具体 State：Chest 查询通用状态，不存在时按自身 Definition 创建并登记 ChestState，存在时由 Chest 确认类型并绑定。目前唯一真实动态对象状态是 ChestState 的 CLOSED / OPEN。Sign 内容属于静态定义，Bed 自身没有需要持续保存的动态事实，三个 Location 也没有可消费的动态状态，因此不为它们建立空 State。

WorldState 中的 `object_id → WorldObjectState`、`character_id → CharacterState` 和独立的 WorldTimeState 是真正的世界事实；已遇到的固定 WorldObject Definition、当前活动 Location、当前活动 WorldObject 和场景来源仅用于登记与开发期错误检查，不表达世界发生了什么，也不会混入具体 State。

Scene Node 被释放不代表对应世界事实被删除。Chest Node 加载时按 `object_id` 绑定已有 ChestState，Action 成功后修改这份状态并更新表现；酒馆卸载后 ChestState 继续存在，新 Chest Node 会重新绑定同一事实。固定对象 Definition 登记记录初始 Location 和对象类型，只用于发现两个场景定义误用同一 ID，不表示 `object_id` 永久属于某个 Location。

未来可移动对象的 `current_location`、`current_cell` 和 orientation 应属于其动态 State。对象从一个位置移动到另一个位置不会改变 `object_id`。当前没有家具移动需求，因此不提前建立 Furniture、移动状态或布置系统。

Location 的格子索引仍是当前已加载 Scene 的局部查询结构，不是 World State。当前运行时 WorldState 也不是磁盘存档；未来 Save / Load 应序列化这份世界事实结构，而不是建立另一套权威。当前不实现文件格式、版本迁移或存档槽。

## 统一世界时间

世界时间是世界级事实，不属于某个 WorldObject，也不依附当前加载的 Location Scene。WorldTimeState 与 WorldObjectState 分离，当前只保存一个权威基础量 `total_minutes`。年、月、日、时、分、星期和季节全部由该值及统一日历规则推导，不作为平行字段重复保存，因而不存在多个日期字段相互失配的问题。

WorldState 持有 WorldTimeState，使它与其他运行时世界事实一样跨 Location Scene 生命周期持续存在。独立的 WorldTime 运行时服务负责解释并改变这份事实，包括帧率无关的自然流逝、按分钟推进、推进到指定未来时刻、日历换算以及变化通知。Location、HUD 和具体 WorldObject 不各自维护当前时间，也不直接操作 `total_minutes`。

当前日历常量集中在同一处：一年 12 个月、每月 30 天、一周 7 天、一天 24 小时、每小时 60 分钟；第一年一月一日是 Monday，四季各覆盖连续三个月。运行时初始事实是第一年一月一日 08:00。自然时间使用小数秒累积，当前统一速率是 1 个真实秒对应 1 个游戏分钟；时间节点遵循 SceneTree 暂停，不在暂停期间自然推进。

时间服务在推进后通知总分钟变化，并分别报告跨过的分钟、绝对小时边界和绝对天边界。一次大跨度推进只需一次通知即可携带变化前后范围与跨越数量，未来消费者能够据此处理所有跨界，不必假定每次只增加一分钟。当前不在时间系统中预建事件调度器或 NPC 日程系统。

睡眠仍沿用正式 Action 链：公共空间规则和 Bed 自身规则通过后，Bed 请求 WorldTime 推进到下一天 08:00；日期进位与跨月、跨年计算由时间服务负责。Bed 不保存另一份日期，不直接写 WorldTimeState，也没有因此产生 BedState。HUD 属于 Presentation，只订阅时间变化并读取派生值进行显示，不拥有或修改世界时间。

## Character Definition、State、Registry 与表现

Character 是独立于 Godot Scene Node 的持续世界实体。当前逻辑 Character 只关联同一 `character_id` 下的 CharacterDefinition 与 CharacterState，不承担场景表现职责。

CharacterDefinition 回答“这个角色是什么”，当前仅保存 UUID v4 `character_id`、`display_name` 和指向 Texture2D 的 `visual_ref`。CharacterState 回答“这个角色在当前世界状态下是什么样”，当前仅保存同一个 `character_id`、`current_location_id`、Location 内的连续 `local_position` 和四方向 `facing`。Definition 不保存当前位置，State 不复制名称或视觉引用；角色初始位置属于初始 CharacterState，不是永久 Definition。

Character Registry 是当前世界中 Character 的权威集合，以 UUID 为主键，支持 Character 注册、按 ID 获取与存在性查询、稳定遍历以及按当前 Location 查询。它只维护 `character_id → Character` 索引并校验 Character 内部的 Definition / State 身份一致性；CharacterState 由启动入口显式交给 WorldState 持有。Registry 不创建角色、不判断谁受玩家控制，也不加载 Location 或 Presentation；UUID Generator 不承担 Registry 职责。

Location 加载时，游戏从 Registry 查询 `CharacterState.current_location_id` 等于该 Location 的角色，为每个角色实例化同一个 CharacterPresentation Scene，并按 CharacterState 恢复局部位置和朝向。CharacterPresentation 读取 `CharacterDefinition.visual_ref`，加载 Texture2D 后设置共享结构中的 Sprite2D。Location 卸载前，Presentation 把当前局部位置同步回同一 CharacterState；随后 Node 可以释放，而 Character、Definition 和 State 继续存在。再次加载时会创建新的表现 Node 并绑定相同逻辑角色、状态和视觉纹理。当前 Game 临时从 `player.json` 加载 Player Definition，以既有初始值创建并登记 Player State 和 Character；Martha Definition 数据仍然有效，但在通用 NPC 初始化流程出现前不创建 State、Character 或 Presentation。

Character 从 CharacterState 的连续局部位置可靠推导当前格子，并提供 facing 相邻格给现有空间规则，不重复保存格子状态。所有当前普通角色共用包含 Sprite2D 和 CollisionShape2D 的 CharacterPresentation Scene；脚本只承担已加载 Location 中的视觉绑定、空间表现、碰撞、状态恢复与同步，不定义具体角色外观。PlayerController 独立持有当前受控 Character 和它在已加载 Location 中的 CharacterPresentation，负责输入、连续移动、交互 Action 请求、结果信号和 Camera；Location 切换后重新绑定同一个 Character 的新 Presentation。Character 与 CharacterPresentation 都不保存 Player 标记，Player 只表示当前控制权。WorldAction 的 Actor 是逻辑 Character，不是 Controller 或临时 Presentation Node。

## 当前交互与行为关系

玩家按下统一交互输入时，PlayerController 请求 InteractionTargetSelector 先查询当前受控 CharacterPresentation facing 方向的相邻格，再查询其当前格。查询直接使用当前 Location 的 WorldObject 格子索引，不遍历 SceneTree。每个格子只选择一个支持行为的对象；同格多个候选按稳定 `object_id` 排序，保证结果简单且确定。这一过程只负责确定玩家意图的目标，不让各个对象分别监听输入，也不是 Action 合法性的唯一防线。

选中目标后的当前基础关系是：

```text
PlayerController 把玩家输入转化为移动或交互意图
  ↓
CharacterPresentation 绑定 Character、执行当前 Scene 中的空间移动并同步状态
  ↓
Location / GridScene 维护自身格子中的 WorldObject
  ↓
InteractionTargetSelector 根据当前 Presentation 选择 Actor 想操作的目标
  ↓
WorldAction 表达逻辑 Character Actor、行为身份和目标
  ↓
公共空间规则验证同一 Location 与当前格 / facing 相邻格
  ↓
WorldObject 自身行为规则
  ↓
执行并修改运行时 World State
  ↓
Scene Node 根据结果更新当前表现
  ↓
ActionResult（success / failure、消息与失败代码）
  ↓
Presentation 显示结果
```

公共空间规则属于 WorldAction 执行链，先验证 Actor 与目标有效、属于同一个 Location，并且目标占据 Actor 当前格或 facing 相邻格；通过后才进入具体 WorldObject 的行为规则和执行。即使 NPC、AI 或其他系统绕过玩家 Selector 直接创建 WorldAction，非法空间行为也不能修改目标状态。

行为合法性判断与合法行为的执行保持分离。PlayerController 只产生玩家意图并发出结果，不直接修改箱子等对象的状态，也不直接更新交互结果 UI。空间拒绝同样返回正式 ActionResult 和明确失败代码。合法 Chest Action 修改权威 ChestState，Node 只根据同一状态更新视觉。正式结果不只服务玩家画面；未来 NPC 或 AI 发起行为时，也应能得到相同的成功、失败和原因信息。

## 世界事实的权威边界

World State 记录已经成立的世界事实，但事实不能仅凭输入、角色意图、模拟建议、表现效果或生成内容而成立。确定性的世界状态变化必须来自经过 World Rules 验证、并由游戏系统执行的结果。

玩家和 NPC 都是世界中的 Actors。当两者采取本质相同的行为时，应由同一个世界中的游戏规则判断，而不是因为控制来源不同就天然获得不同的规则权威。

World Simulation 可以推动时间并发起非玩家直接驱动的变化，但这些变化仍需遵守世界规则。它负责让世界运转，不因此获得绕过规则修改事实的权力。

## AI 的权威边界

AI 是内容与决策建议来源，不是世界权威。它可以提出角色可能采取的行动、生成开放性内容或为系统提供建议，但不能直接宣布行动成功、物品出现、角色状态改变或其他世界事实已经发生。

AI 参与世界变化时必须遵循：

```text
AI 提议 → 游戏规则验证 → 游戏系统执行 → World State 改变
```

AI 的输出即使被接受，也必须通过与该行为相适应的规则和执行过程。

## Presentation 与逻辑世界

PlayerController 负责把玩家输入转化为可供游戏处理的意图；CharacterPresentation 与其他 Presentation 负责把世界状态和行为结果呈现为 Godot 场景、画面、UI、声音及反馈。

Presentation 可以维护表现所需的临时状态，但不能把画面上看似发生的事情直接当作已经成立的世界事实。逻辑世界也不应依赖某个特定界面或验证场景才能成立。

当前 Chest Scene 按稳定 `object_id` 绑定运行时 ChestState；角色表现按 `character_id` 绑定 CharacterDefinition 与 CharacterState。两者都允许 Scene Node 随 Location 加载和卸载，而权威动态状态继续存在。其他 Scene 与逻辑世界的绑定只在出现真实需求时决定。

## 暂不规定的实现事项

除已由实际功能建立的当前边界外，本文不提前规定未来的类、文件、JSON Schema、Godot Node 或 Resource 选择、signal、Manager、API、存档格式和具体算法。它们应在对应需求清楚后单独设计。
