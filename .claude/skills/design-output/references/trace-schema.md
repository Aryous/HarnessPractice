# 消费端 trace sidecar Schema

与 `arch-output` 的消费端 schema 相同。详见 `.claude/skills/arch-output/references/trace-schema.md`。

此处列出要点供快速参考，完整定义以 arch-output 为准。

## 快速参考

```yaml
document: docs/design-docs/design-spec.md
role: consumer
trace_from: docs/product-specs/requirements.trace.yaml
generated_by: design

entries:
  - input: R1.1
    disposition: covered
    output: §组件规范 — 编辑器
    note: 编辑器布局与交互规范
  - input: R1.2
    disposition: excluded
    reason: 纯技术实现，无 UI 表面
```

### disposition 值

| 值 | 含义 | 必填字段 |
|---|---|---|
| covered | 已覆盖 | output |
| excluded | 显式排除 | reason |
| partial | 部分覆盖 | output + reason |

### 覆盖范围

只覆盖用户可见的需求条目（有 UI/UX 含义的）。
纯技术实现条目（如 R1.2 持久化、R3.2 多供应商配置）可 excluded。
未出现在 entries 中的条目视为"与本文档无关"。
