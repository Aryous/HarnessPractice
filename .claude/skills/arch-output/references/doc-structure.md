# ARCHITECTURE.md 文档结构契约

## Frontmatter

```yaml
---
status: draft | review | approved
author: architecture-bootstrap
date: YYYY-MM-DD
blocks: [tech-selection, design, feature]
open_questions: 0
---
```

- `approved` 时 `open_questions` 必须为 0
- 文档中仍有未决 Q 时，status 必须保持 `review`

## 章节结构

```
# 架构文档

> 权威声明

## 域分层模型
（ASCII 图：各层名称与职责）

## 依赖规则
（表格：每层的允许引用 / 禁止引用）

## 横切关注点
（唯一入口清单，每个必须标注文件路径）

## 目录结构映射
（src/ 树形结构 ← 映射到分层模型）

## 机械化强制执行
（ESLint 规则 / 结构测试 / CI 流水线）

## 待人类裁决（如有）
（按上报协议格式）
```

## 文档只回答四件事

1. 系统按什么层次组织
2. 每层允许和禁止依赖什么
3. 哪些横切能力必须通过唯一入口进入
4. 当前目录如何映射到这些边界

超出这四件事的内容不属于架构文档。

## 禁止事项

- 不得把具体库选型写成架构不变量（"用 Zustand" 是技术决策，不是架构约束）
- 不得写实现细节（"函数签名" 不属于架构文档）
- 若已有 `src/`，目录映射必须忠实反映当前结构
- 不得将 status 设为 approved（由人类审批）
