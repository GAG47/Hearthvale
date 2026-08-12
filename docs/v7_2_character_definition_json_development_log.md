# V7.2 CharacterDefinition JSON 数据化开发日志

日期：2026-08-12

## 本次目标

V7.2 为 Player 与 Martha 的静态 CharacterDefinition 新增可校验的 JSON 数据入口，为内容与运行逻辑分离建立最小基础。本版本不改变 CharacterState，也不让 Loader 接管现有 CharacterRegistry 硬编码初始化链。

## Character 数据

新增两份角色数据：

- `data/characters/player.json`；
- `data/characters/martha.json`。

当时的 CharacterDefinition 数据边界只有 `character_id`、`display_name` 与 `presentation_ref`。角色 UUID、名称和表现 Scene 路径保持原有值；当前 Location、局部位置和朝向继续只属于 CharacterState，没有进入 JSON。

## CharacterDefinitionLoader

新增 CharacterDefinitionLoader，从文件读取 JSON 并逐项验证：

- 文件可读取且 JSON 语法有效；
- 根节点是 Dictionary；
- 三个必需字段存在且类型正确；
- `character_id` 是合法 UUID v4；
- `display_name` 非空；
- `presentation_ref` 指向存在的资源。

任何失败都会给出明确错误并返回空结果，不生成默认 UUID，不补齐字段，也不静默修正数据。Loader 只构造 CharacterDefinition，不创建 CharacterState、Presentation 或 Registry 内容。

## 测试与路径修正

新增独立 headless 测试脚本和正反例 fixtures，覆盖两份正式数据以及文件、JSON、字段、UUID 和资源引用失败。随后修正 Tavern、Town Street 与 Tavern Yard 中因 V7.1 目录移动遗留的 Location 脚本路径。

V7.2 的数据入口为后续版本使用；本版本运行时仍保留原有 CharacterRegistry 硬编码初始化链，因此没有改变玩家生成、移动、Location 切换或 Martha 的表现行为。
