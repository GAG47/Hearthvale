# V7.1 脚本领域目录整理开发日志

日期：2026-08-12

## 本次目标

V7.1 只整理已经存在的脚本目录，使路径更清楚地表达领域归属，不改变角色、Location、World State、交互或运行规则。

## 目录调整

角色逻辑脚本移动到 `scripts/characters/`：

- `character.gd`；
- 对应的 Godot UID 文件。

Location 场景职责脚本移动到 `scripts/location/`：

- `grid_scene.gd`；
- `location_entry.gd`；
- `location_exit.gd`；
- 对应的 Godot UID 文件。

这些改动为后续 Character 数据化与表现层整理建立了明确目录边界。V7.1 没有新增抽象、数据字段或运行功能；移动后仍残留的三个 Location Scene 脚本路径在 V7.2 中完成修正。

## 范围

本版本是纯目录整理，共移动八个文件（四个脚本及其 UID），没有修改其内容。历史结构中的 `Character`、`CharacterState` 与 Location 运行职责保持不变。
