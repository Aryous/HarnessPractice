# 设计文档结构契约

## 产物总览

| 文件 | 角色 | 触发条件 |
|---|---|---|
| design-spec.md | 设计阶段真相源 | 每次模式 A 必须产出 |
| design-spec.trace.yaml | 消费端 sidecar | 与 design-spec.md 同步 |
| classical-tokens.md | token/组件定义参考 | token 清单变更时更新 |
| ai-interaction-spec.md | AI 交互专项规范 | AI 交互议题被要求时 |
| index.md | 设计文档索引 | 任一产物变更时更新 |

---

## design-spec.md

### Frontmatter

```yaml
---
status: draft | review | approved
author: design
date: YYYY-MM-DD
blocks: [design-phase-b, feature]
open_questions: 0
---
```

- `approved` 时 `open_questions` 必须为 0
- 文档中仍有未决 Q 时，status 必须保持 `review`

### 章节结构

design-spec.md 的章节组织由设计内容驱动，不做硬性规定。
但必须包含以下类别的内容：

1. **设计原则** — 视觉语言的核心约束
2. **色彩体系** — 色板定义、语义色、用途映射
3. **字体排版** — 字体族、字号层级、行高
4. **间距与布局** — 间距尺度、网格系统、断点
5. **组件规范** — 原子组件的视觉规范（按钮、输入框、卡片等）
6. **页面规范** — 页面级别的布局与交互规范
7. **动画规范** — 动画时长、缓动曲线、触发条件

### 权威性声明

> 此文档是所有 UI 工作的权威约束。
> 任何视觉决策必须在此文档中有据可循，否则不得实施。

---

## classical-tokens.md

### 定位

token/组件定义参考。记录 `src/ui/tokens/index.css` 中的设计令牌和组件令牌。

### 结构

```
# 设计令牌参考

> 令牌文件: src/ui/tokens/index.css
> 权威来源: docs/design-docs/design-spec.md

## L1 基础色（中国传统色）
（表格：CSS 变量 / 色值 / 传统色名 / 用途）

## L2 语义色
（表格：CSS 变量 / 映射 / 用途）

## L3 组件令牌
（表格：CSS 变量 / 映射 / 用途）

## 排版令牌
## 间距令牌
## 动画令牌
...
```

### 约束

- **只能描述已存在的 token** — 不得凭空发明
- 每个令牌必须标注 CSS 变量名、值、用途
- 权威来源是 design-spec.md，本文件是实现参考

---

## ai-interaction-spec.md

### Frontmatter

```yaml
---
status: draft | review | approved
author: design
date: YYYY-MM-DD
blocks: [feature]
open_questions: 0
---
```

### 定位

AI 交互专项规范。定义 AI 面板的交互模型、prompt 架构、UI 形态。
仅在 AI 交互议题被明确要求时产出或修订。

### 结构

```
# 墨灵交互模型

> 权威约束声明

## 诊断（如有）
（当前系统的 UX 审计与问题识别）

## 交互模型
（对话式/面板式/混合式的交互定义）

## UI 形态
（组件布局、状态流转、视觉规范）

## Prompt 架构
（system prompt 结构、上下文组织、路由逻辑）

## 待人类裁决（如有）
```

---

## index.md

### 结构

```
# 设计文档索引

> 本目录只包含 design agent 的正式产物。

| 文件 | 主题 | owner | 状态 | 更新日期 |
|---|---|---|---|---|
```

每当产物列表或状态变更时同步更新。

---

## 禁止事项

- classical-tokens.md 只能描述已存在的 token/组件，不得凭空发明
- 不得将 status 设为 approved（由人类审批）
