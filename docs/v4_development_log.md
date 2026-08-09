# V4 世界时间系统开发日志

日期：2026-08-10

## 目标与边界

本次建立整个运行中世界共用的统一时间，使时间成为独立于 Godot Location Scene 生命周期的世界事实，并让自然流逝、显式推进、睡眠与 HUD 都使用同一权威来源。

本次没有实现 NPC 日程、预约事件系统、营业时间、昼夜光照、天气、疲劳、睡眠质量、睡眠危险、时间倍率选项、离线推进或磁盘 Save / Load。

## 权威时间事实

新增 `WorldTimeState` 作为世界级 State。它不继承 WorldObjectState，也不使用 `object_id`，当前只保存：

```text
total_minutes: int
```

`total_minutes` 从第一年一月一日 00:00 起累计。当前初始值是 480，对应第一年一月一日 08:00。年、月、日、时、分、星期和季节均在读取时推导，不保存重复日期字段。

WorldState 持有唯一 WorldTimeState。Location Scene 的建立、卸载和切换不会创建、替换或清除它。WorldState 仍不执行日历换算或自然推进；这些职责属于 WorldTime。

## 日历规则

`WorldCalendar` 集中保存并解释当前日历常量：

| 项目 | 规则 |
| --- | --- |
| 年 | 12 个月 |
| 月 | 30 天 |
| 周 | 7 天 |
| 日 | 24 小时 |
| 小时 | 60 分钟 |
| 星期起点 | 第一年一月一日为 Monday |
| Spring | 月份 1–3 |
| Summer | 月份 4–6 |
| Autumn | 月份 7–9 |
| Winter | 月份 10–12 |

所有面向玩家的年、月、日从 1 开始。转换函数同时提供合法日期校验与日期到 `total_minutes` 的单向换算，不引入现实闰年、不同月长或现实历法规则。

## WorldTime 运行时服务

`WorldTime` 是独立 Autoload，在 WorldState 之后加载。它从 WorldState 取得或初始化唯一 WorldTimeState，并统一提供：

- 当前总分钟及年、月、日、时、分、星期、季节查询；
- `advance_minutes()` 按正分钟推进；
- `advance_to()` / `advance_to_total_minutes()` 推进到指定未来时刻；
- `advance_to_next_day_at()` 负责下一天指定时刻的日期计算；
- 自然时间流逝；
- 分钟、小时、日期边界和任意时间变化通知。

时间只允许向未来推进。无效日期、倒退目标或缺失 WorldTimeState 会明确报错并拒绝改变事实。

分钟变化信号携带变化前后 `total_minutes` 和跨越分钟数；小时与日期信号携带变化前后绝对边界索引及跨越数量。睡眠等一次推进大量分钟的行为因此能够明确报告所有跨过的小时与日期，而不需要逐分钟发出大量事件。当前没有建立通用时间事件 Scheduler。

## 自然流逝与暂停

自然流逝的统一配置是：

```text
REAL_SECONDS_PER_GAME_MINUTE = 1.0
```

WorldTime 在 `_process(delta)` 中累积小数真实秒，只在累积达到完整游戏分钟时改变权威状态，因此不依赖帧率，也不会丢失不足一分钟的时间片。WorldTime 使用可暂停处理模式；SceneTree 暂停时自然时间停止。

显式推进与自然流逝共用同一个 `advance_minutes()` 入口和同一套变化通知。Location 不拥有自己的计时器或当前时间。

## Bed 睡眠行为

Bed 的 `sleep` 不再固定失败。它仍通过 InteractionTargetSelector、WorldAction、公共空间规则和 Bed 行为规则执行；规则允许且 WorldTime 可用时，Bed 请求时间服务推进到下一天 08:00。

Bed 只声明本次睡眠的醒来时刻，不计算当前日期、下一天、月末或年末，也不直接修改 WorldTimeState。跨日、跨月和跨年的计算全部由 WorldTime 负责。睡眠成功返回正式 ActionResult；当前不增加 BedState、疲劳、睡眠质量、打断或额外后果。

## HUD 表现

主场景 HUD 新增只读时间面板，显示：

- `Year / Month / Day`；
- 星期；
- `HH:MM`；
- 季节。

Game 在加载时读取 WorldTime，并订阅统一 `time_changed` 信号刷新面板。HUD 不自行计时、不执行日历换算，也不修改世界事实。当前面板只是基础调试与验证表现，不涉及正式 UI 风格设计。

## 修改文件

新增：

- `scripts/world_time/world_time_state.gd`；
- `scripts/world_time/world_calendar.gd`；
- `scripts/world_time/world_time.gd`；
- `docs/v4_development_log.md`。

修改：

- `project.godot`：登记 WorldTime Autoload；
- `scripts/world_state/world_state.gd`：持有和登记唯一 WorldTimeState；
- `scripts/world_objects/bed.gd`：睡眠改为通过统一时间服务推进；
- `scripts/game.gd`：读取时间并刷新 HUD；
- `scenes/main.tscn`：增加日期、星期/季节和时钟显示；
- `docs/design.md`：记录统一世界时间的游戏设计方向；
- `docs/architecture.md`：记录时间事实、时间服务和 Presentation 的权威边界。

## Godot 4.7.1 实际验证

使用 Godot 4.7.1 完成确定性运行验证：

- 初始时刻为第一年一月一日 08:00，星期 Monday，季节 Spring；
- 23:59 加一分钟正确进入次日 00:00；
- 第一月第 30 日 23:59 加一分钟正确进入第二月第一日；
- 第一年第 12 月第 30 日 23:59 加一分钟正确进入第二年第一月第一日；
- 星期从 Monday 到 Sunday 后按七天正确回到 Monday，并连续跨越年界；
- 月份 1、4、7、10 分别得到 Spring、Summer、Autumn、Winter；
- 大跨度推进的分钟、小时、日期信号均报告正确前后范围与跨越数量；
- 从任意时刻睡眠正确到下一天 08:00；
- 在月末和年末睡眠分别正确跨月、跨年；
- HUD 初始显示和时间变化后的显示均与权威时间一致；
- 酒馆、小镇街道、酒馆后院往返后 `total_minutes` 保持同一事实，没有随 Location Scene 重置；
- Chest 开启状态继续跨 Location 保持，Sign inspect、四方向连续移动与禁止对角移动没有回归。

另以正常自然流逝实际等待 60.11 个真实秒，世界推进 60 个游戏分钟，HUD 从 08:00 显示到 09:00。随后暂停 SceneTree 1.2 秒，世界时间未变化。

## 当前限制

世界时间当前只在一次游戏运行内持续，退出进程后不会写入磁盘。统一速率暂时固定为每真实秒一个游戏分钟，没有快进、倍速或设置界面。现有时间变化信号提供未来系统所需的边界信息，但没有提前实现事件队列、角色日程、昼夜表现、天气或营业规则。
