---
name: design-output
description: >
  design agent 的输出契约。定义 design-spec.md 文档结构和消费端 trace
  sidecar schema。当 design agent 产出或修订设计规范时触发。
  仅适用于模式 A（设计规范），模式 B（设计实现）不触发本 Skill。
---

# design-output：设计规范输出契约

## 产物

模式 A 的产物清单：

| 文件 | 性质 | 说明 |
|---|---|---|
| `docs/design-docs/design-spec.md` | 必须 | 设计阶段真相源 |
| `docs/design-docs/design-spec.trace.yaml` | 必须 | 消费端 sidecar |
| `docs/design-docs/classical-tokens.md` | 按需 | token/组件定义参考，只描述已存在的 |
| `docs/design-docs/ai-interaction-spec.md` | 按需 | AI 交互专项规范 |
| `docs/design-docs/index.md` | 必须 | 设计文档索引，产物变更时同步更新 |

design-spec.md 与 sidecar 必须同步更新。只改一个不改另一个视为不合格交付。

## 文档结构

详见 `references/doc-structure.md`。

核心规则：
- design-spec.md 是设计阶段唯一真相源
- 必须覆盖 requirements.md 中每个用户可见需求
- frontmatter 必须包含 status / author / date / blocks / open_questions

## Sidecar Schema

消费端 schema，详见 `references/trace-schema.md`。

核心规则：
- sidecar 角色为 `consumer`，声明对上游 requirements 条目的覆盖关系
- 只覆盖用户可见的需求条目（有 UI/UX 含义的）
- 纯技术实现条目（如 R1.2 持久化）可 excluded
