# 消费端 trace sidecar Schema

与 `arch-output` 的消费端 schema 相同。详见 `.claude/skills/arch-output/references/trace-schema.md`。

此处列出要点供快速参考，完整定义以 arch-output 为准。

## 快速参考

```yaml
document: docs/tech/tech-decisions.md
role: consumer
trace_from: docs/product-specs/requirements.trace.yaml
generated_by: tech-selection

entries:
  - input: R1.2              # 上游条目 ID
    disposition: covered      # covered / excluded / partial
    output: 决策 3            # 本文档中的覆盖位置
    note: IndexedDB / Dexie 方案
```

### disposition 值

| 值 | 含义 | 必填字段 |
|---|---|---|
| covered | 已覆盖 | output |
| excluded | 显式排除 | reason |
| partial | 部分覆盖 | output + reason |

### 覆盖范围

只覆盖有技术含义的需求条目。纯 UI/UX 需求（如 R4.1 古风视觉体系）可 excluded。
未出现在 entries 中的条目视为"与本文档无关"。
