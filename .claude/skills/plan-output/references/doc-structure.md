# 执行计划文档结构契约

## Frontmatter

```yaml
---
status: draft | review | approved
author: plan
date: YYYY-MM-DD
blocks: [feature]
open_questions: 0
priority: P0 | P1 | P2
scope: [关联的 R/F ID 列表]
---
```

- `blocks: [feature]` — exec-plan 阻塞 feature agent
- `scope` 列出本计划覆盖的 trackable ID（从 requirements.trace.yaml）
- `approved` 时 `open_questions` 必须为 0

## 章节结构

### § 目标

一句话描述这个计划要完成什么。

### § 背景

为什么需要做这件事。关联的需求条目、问题诊断、技术约束。

### § 验收标准

可检验的标准列表（checkbox 格式）。每条标准必须是可观测的——"通过""可用""可见"，不是"差不多""基本上"。

```markdown
- [ ] Ctrl+Z 撤销最近一次编辑
- [ ] npx tsc -b --noEmit 通过
```

### § 实施步骤（Task 列表）

按执行顺序排列的 task 列表。每个 task 包含：

```markdown
## Task N: [标题]

**关联**: R1.1, F05
**依赖**: Task M（如有）

[描述做什么、为什么这样做]

**影响文件**:
- `src/path/file.ts` — 新建 | 修改
- `tests/path/file.test.ts` — 新建

[可选：伪代码或接口签名辅助理解]
```

约束：
- 每个 task 至少关联一个 R 或 F ID
- task 之间的依赖显式标注
- 不写生产代码，可用伪代码或接口签名

### § 涉及文件

汇总所有 task 涉及的文件路径。

### § 依赖

前置条件或依赖的其他计划。

### § 溯源表

```markdown
| 输入条目 | 处理 | Task | 备注 |
|---|---|---|---|
| R1.1 | 已覆盖 | Task 1, Task 3 | — |
| F05 | 已覆盖 | Task 2 | — |
| R4.1 | 显式排除 | — | v1 不含 |
```

处理类型：`已覆盖` / `显式排除` / `部分覆盖`。

### § 待人类裁决（如有）

按上报协议格式。有未决 Q 时 status 必须保持 review。
