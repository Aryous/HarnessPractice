---
name: plan-output
description: >
  plan agent 的输出契约。定义 exec-plan 文档结构和消费端 trace sidecar schema。
  当 plan agent 产出或修订执行计划时触发。
---

# 执行计划输出契约

## 产物

| 文件 | 角色 | 位置 |
|---|---|---|
| `<name>.md` | 执行计划文档 | `docs/exec-plans/active/` |
| `<name>.trace.yaml` | 消费端 sidecar | `docs/exec-plans/active/` |

命名规范：`<name>` 为描述性 slug（如 `f05-undo-redo`、`ui-refinement`）。

## 结构契约

- 文档结构：[references/doc-structure.md](references/doc-structure.md)
- Sidecar schema：[references/trace-schema.md](references/trace-schema.md)

## 禁止事项

- 不得将 status 设为 approved（由人类审批）
- 不得写生产代码，可用伪代码或接口签名
