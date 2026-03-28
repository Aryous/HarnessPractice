# 消费端 trace sidecar Schema

## 角色

消费端 sidecar 声明本文档对上游 requirements 条目的覆盖关系。
这是所有非 requirements 文档共用的 sidecar 模式。

## 完整 Schema

```yaml
# .claude/ARCHITECTURE.trace.yaml
document: .claude/ARCHITECTURE.md
role: consumer
trace_from: docs/product-specs/requirements.trace.yaml
generated_by: architecture-bootstrap

entries:
  - input: R1.1                  # 上游条目 ID
    disposition: covered          # 覆盖状态
    output: §域分层模型, §目录结构映射  # 本文档中的覆盖位置
    note: 编辑器走 UI → Runtime → Service / Repo
  - input: R4.2
    disposition: excluded
    reason: 组件粒度不属于架构层约束
```

## 字段说明

### 顶层字段

| 字段 | 必填 | 说明 |
|---|---|---|
| document | 是 | 本文档路径 |
| role | 是 | 固定为 `consumer` |
| trace_from | 是 | 源头 sidecar 路径 |
| generated_by | 是 | 生成此文件的 agent 名称 |

### entries[]

| 字段 | 必填 | 说明 |
|---|---|---|
| input | 是 | 上游条目 ID（R 或 F） |
| disposition | 是 | 覆盖状态 |
| output | 条件 | covered / partial 时必填，本文档中的覆盖位置 |
| reason | 条件 | excluded 时必填，排除原因 |
| note | 否 | 补充说明 |

### disposition 值

| 值 | 含义 | 必填字段 |
|---|---|---|
| covered | 已覆盖 | output |
| excluded | 显式排除 | reason |
| partial | 部分覆盖 | output + reason（说明未覆盖部分） |

## 覆盖范围

消费端不需要覆盖源头的所有条目。只需覆盖**与本文档职责相关的条目**。

对于 ARCHITECTURE.md，相关条目是有代码组织含义的需求（分层、依赖方向、唯一入口）。
纯 UI 行为（如 F05 撤销/重做）或纯业务逻辑不需要在架构文档中声明覆盖。

未出现在 entries 中的条目视为"与本文档无关"，不视为遗漏。
