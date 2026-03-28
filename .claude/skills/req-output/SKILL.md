---
name: req-output
description: >
  req-review agent 的输出契约。定义 requirements.md 文档结构和
  requirements.trace.yaml sidecar schema。当 req-review agent
  产出或修订需求文档时触发。
---

# req-output：需求文档输出契约

## 产物

每次执行必须同时输出两个文件：

1. `docs/product-specs/requirements.md` — 给人看的需求文档
2. `docs/product-specs/requirements.trace.yaml` — 给脚本读的结构化 sidecar

两个文件必须同步更新。只改一个不改另一个视为不合格交付。

## 文档结构

详见 `references/doc-structure.md`。

核心规则：
- 走查发现的**描述**写入文档正文，保留 F-ID 作为引用锚点
- 走查发现的**结构化表格**（severity / disposition / trackable）不写入文档，由 sidecar 承载
- frontmatter 必须包含 status / author / date / blocks / open_questions

## Sidecar Schema

详见 `references/trace-schema.md`。

核心规则：
- sidecar 角色为 `source`（条目注册表），不是消费端
- 注册两类条目：`requirements`（R）和 `findings`（F）
- F 条目必须声明 `disposition`：open / resolved / discarded / deferred
- `trackable` 列表显式列出 trace.sh 应追踪的 ID，推导规则：disposition 为 open 或 resolved 的 S0/S1 条目
- Q（裁决）不进入 sidecar

## 走查发现处理

1. 识别缺口后，在文档正文中写入发现描述（含 F-ID、关联需求、发现内容）
2. 在 sidecar 的 `findings` 中注册该 F 条目（含 severity、disposition 等结构化字段）
3. 根据 disposition 决定是否加入 `trackable`
4. 已裁决的 Q 如果关联了 F，文档正文中保留 `[FXX]` 引用，sidecar 不记录 Q
