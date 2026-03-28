---
name: arch-output
description: >
  architecture-bootstrap agent 的输出契约。定义 ARCHITECTURE.md 文档结构
  和消费端 trace sidecar schema。当 architecture-bootstrap agent
  产出或修订架构文档时触发。
---

# arch-output：架构文档输出契约

## 产物

每次执行必须同时输出两个文件：

1. `.claude/ARCHITECTURE.md` — 给人看的架构契约
2. `.claude/ARCHITECTURE.trace.yaml` — 给脚本读的消费端 sidecar

两个文件必须同步更新。只改一个不改另一个视为不合格交付。

## 文档结构

详见 `references/doc-structure.md`。

核心规则：
- 只写不变量，不写实现细节
- 不得把具体库选型写成架构约束
- 分层规则、依赖方向、唯一入口是三个必要章节
- frontmatter 必须包含 status / author / date / blocks / open_questions

## Sidecar Schema

详见 `references/trace-schema.md`。

核心规则：
- sidecar 角色为 `consumer`（消费端），声明对上游 requirements 条目的覆盖关系
- `trace_from` 指向源头 `requirements.trace.yaml`
- 每个上游条目必须声明 disposition：covered / excluded / partial
- covered 必须标注 output 位置，excluded 必须说明原因
