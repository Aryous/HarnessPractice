# ARCHITECTURE.md 文档结构契约

## Frontmatter

```yaml
---
status: draft | review | approved
author: architecture-bootstrap
date: YYYY-MM-DD
blocks: [tech-selection, plan, design, feature]
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

## 层间契约
（每层向上暴露的接口清单：导出的数据类型 / 函数签名 / 事件）
（这是 design Agent 的上下文来源——它只读本章节的 types 和 runtime 部分）

## 横切关注点
（唯一入口清单，每个必须标注文件路径）

## 目录结构映射
（src/ 树形结构 ← 映射到分层模型）

## 机械化强制执行
（指向同批次产出的 linter 规则文件的路径，不只是描述。
首次 bootstrap 如 tech-decisions 未产出，标注 pending_tech_stack，
tech-selection 完成后由增量修订翻译为具体实现。）

## 待人类裁决（如有）
（按上报协议格式）
```

## 文档回答五件事

1. 系统按什么层次组织
2. 每层允许和禁止依赖什么
3. 每层向上暴露什么接口（导出的数据类型 / 函数签名 / 事件）
4. 哪些横切能力必须通过唯一入口进入
5. 当前目录如何映射到这些边界

超出这五件事的内容不属于架构文档。

## 禁止事项

- 不得把具体库选型写成架构不变量（"用 Zustand" 是技术决策，不是架构约束）
- 不得写实现细节（内部逻辑、算法、私有函数等不属于架构文档；层间契约中的公开接口签名除外）
- 若已有 `src/`，目录映射必须忠实反映当前结构
- 不得将 status 设为 approved（由人类审批）
