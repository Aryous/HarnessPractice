---
name: tech-output
description: >
  tech-selection agent 的输出契约。定义 tech-decisions.md 文档结构
  和消费端 trace sidecar schema。当 tech-selection agent
  产出或修订技术决策文档时触发。
---

# tech-output：技术决策文档输出契约

## 产物

每次执行必须同时输出两个文件：

1. `docs/tech/tech-decisions.md` — 给人看的技术决策文档
2. `docs/tech/tech-decisions.trace.yaml` — 给脚本读的消费端 sidecar

两个文件必须同步更新。只改一个不改另一个视为不合格交付。

## 文档结构

详见 `references/doc-structure.md`。

核心规则：
- 每个决策必须记录背景、候选方案、最终决策、选择理由、未选原因、约束
- 不得只给推荐不记录为什么没选别的
- 不得提出违反 ARCHITECTURE.md 的依赖方向
- frontmatter 必须包含 status / author / date / blocks / open_questions

## Sidecar Schema

消费端 schema 与 arch-output 相同，详见 `references/trace-schema.md`。

核心规则：
- sidecar 角色为 `consumer`，声明对上游 requirements 条目的覆盖关系
- 只覆盖有技术含义的需求条目，纯 UI/UX 条目不需要覆盖
