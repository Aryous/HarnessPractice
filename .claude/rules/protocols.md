# 系统链接协议

本文件定义系统中所有元素之间的交互规则。所有 Agent 必须遵守。

---

## 协议一：交接协议（Agent → 主控 → Agent）

### 文档状态

每个 Agent 的输出文档必须包含 YAML frontmatter：

```yaml
---
status: draft | review | approved
author: agent-name
date: YYYY-MM-DD
blocks: [downstream-agent-1, downstream-agent-2]
open_questions: 0
---
```

**状态流转**：
- `draft` → Agent 正在写，下游禁止消费
- `review` → Agent 写完，等待人类审批
- `approved` → 人类审批通过，主控可执行阻塞门并启动下游

**状态不变量**：
- `approved` = 下游可以直接消费，不再等待人类判断
- `approved` 文档必须满足 `open_questions: 0`
- 文档中若仍有未决 `Q`，状态必须保持在 `review`
- 发现“`approved` + 未决 Q”时，主控应先修正文档状态，再推进下游

### 溯源表（必须）

每个 Agent 的输出文档必须包含溯源表，列出对上游每个输入条目的处理结果：

```markdown
## 溯源表

| 输入条目 | 处理 | 输出位置 | 备注 |
|---|---|---|---|
| R1.1 简历内容编辑 | 已覆盖 | §3.2 组件规范 | — |
| F05 撤销/重做 | 显式排除 | — | v1 不含，已上报 |
| R2.1 Typst 渲染 | 已覆盖 | §4.1 渲染管线 | — |
```

**处理类型**：
- `已覆盖` — 必须标注输出位置，主控会验证该位置确实存在
- `显式排除` — 必须说明原因（如"不在范围内"、"已上报待裁决"）
- `部分覆盖` — 标注已覆盖和未覆盖的部分

**没有溯源表的 Agent 输出视为不合格，主控将退回。**

### 阻塞门

主控（不是 Agent 自己）在每次交接时执行阻塞门检查：

1. 提取上游文档的全部条目 ID
2. 读取 Agent 输出的溯源表
3. 逐条校验：
   - 每个输入 ID 是否出现在溯源表中
   - 「已覆盖」标注的位置是否真实存在对应内容
   - 「显式排除」的理由是否合理
4. **缺失条目 > 0 → FAIL**，退回 Agent 补全
5. **全部通过 → PASS**，刷新 `.claude/STATE.yaml`，必要时补记 `.claude/PIPELINE.md` 备注，可启动下游

### 管线门禁定义

| 门 | 上游 → 下游 | 校验内容 |
|---|---|---|
| G1 | intent.md → requirements.md | intent 每个需求点有对应结构化需求条目 |
| G1a | requirements.md → `.claude/ARCHITECTURE.md` | 每个有代码组织含义的需求有对应的层次 / 边界 / 唯一入口约束 |
| G2 | requirements.md → tech-decisions.md | 每个有技术含义的需求有决策记录 |
| G3 | requirements.md → design-spec.md | 每个用户可见需求有设计覆盖 |
| G4 | requirements.md → exec-plan (plan agent) | 每个 trackable ID 映射到至少一个计划任务 |
| G5 | exec-plan → code | `bash .claude/scripts/trace.sh --strict` + lint + typecheck + tests 全部通过；exec-plan 溯源表完整 |

### 交接链路

```
intent.md (approved)
  → [G1] req-review → requirements.md (approved)
  → [G1a] architecture-bootstrap → .claude/ARCHITECTURE.md
  → [G2] tech-selection → tech-decisions.md (approved)
  → 环境搭建
  → [G3] design agent 阶段A → design-spec.md (approved)
  → [G4] plan agent → exec-plan (approved)
  → [G5] feature agent → code
```

---

## 协议二：上报协议（Agent → 人类）

Agent 遇到无法自行判断的问题时，在输出文档末尾添加"待人类裁决"章节。

```markdown
## 待人类裁决

### Q1: [问题标题]
**背景**：[为什么无法自行判断]
**选项**：
- A: [方案描述]
- B: [方案描述]
**影响**：[不同选项对后续工作的影响]
**阻塞**：[哪个 Agent 或阶段被阻塞]
```

**规则**：
- 每个问题必须给出至少两个选项，不得只抛问题
- 必须标明阻塞关系
- Agent 不得对未裁决的问题自行假设答案

---

## 协议三：裁决回注协议（人类 → 系统）

人类做出裁决后，裁决必须写回文档。口头回答对下一个 Agent 不可见。

**回注格式**：在原问题下方追加：

```markdown
**裁决**：[选择的方案]
**裁决人**：[姓名]
**日期**：[YYYY-MM-DD]
**已回注**：[裁决写入了哪个文件的哪个位置]
```

**回注目标**：
- 产品决策 → `docs/product-specs/requirements.md`
- 技术决策 → `docs/tech/tech-decisions.md`
- 行为修正 → `.claude/rules/`
- 设计决策 → `docs/design-docs/`

**裁决产生代码需求时**：
1. 确认对应的 F 条目存在于走查发现表中
2. 如果 F 不存在（裁决发现了新问题）→ 在走查表中新增 F 条目
3. 确保 F 条目的严重性 ≥ S1（否则 trace.sh 不追踪）

**原则**：
- Agent 看不到的知识不存在。
- Q 裁决不直接进入追踪体系。追踪体系只认 R 和 F。如果一个 Q 裁决意味着需要写代码，那一定是因为它在解决某个 F。
- Bug 报告的处理流程见 `.claude/rules/bug-workflow.md`。

---

## 协议四：提交协议（工作完成 → git commit）

每个阶段性工作完成后，**必须立即 commit**。

**commit 前检查**：
1. 相关测试通过
2. Lint 通过（`npm run lint`）
3. 类型检查通过（`npx tsc -b --noEmit`）
4. `bash .claude/scripts/closeout.sh` 通过
5. 需要人类确认才能 commit

**原则**：一个阶段一个 commit。积压变更是技术债。

---

## 协议五：环境进化协议（Agent 失败响应）

Agent 失败时，**禁止简单重试**。诊断：

| 症状 | 诊断 | 修复 |
|---|---|---|
| 输出与预期不符 | 缺上下文 | 补 docs/ |
| 反复同类错误 | 缺约束 | 补 rules/ 或 lint |
| 无法完成任务 | 缺工具 | 补脚本或拆分任务 |
| 产出质量低 | 指令不清晰 | 优化 agent 定义 |

**核心原则**：Agent 失败是环境的信号，不是 Agent 的问题。

---

## 协议六：约束升级协议

同类违规出现 ≥ 3 次，按路径升级：

```
docs/（软约束）→ .claude/rules/（中约束）→ lint 规则（硬约束）
```

约束只升级，不降级。

---

## 协议七：豁免协议（人类批准的受控例外）

若某个门禁被**历史债**阻塞，而当前变更本身已局部闭环，不得口头说“先跳过”。

必须：
1. 创建 `docs/exemptions/*.md`
2. 说明背景、允许跳过的 scope、mode、约束、退出条件
3. 由人类审批，写入 `approved_by` / `approved_date` / `expires`
4. 仅在对应 scope 内生效
5. 提交成功后由脚本自动推进豁免状态，不依赖 Agent 手工回写

当前允许的 scope：
- `trace`

生命周期：
- `draft` / `review`：不可生效
- `approved`：可生效
- `consumed` / `expired` / `revoked`：不可再次生效

模式：
- `one_shot`：只允许放行一次提交，成功后自动改成 `consumed`
- `until_resolved`：允许在 `covers` 声明的历史缺口范围内重复使用，并记录 `last_used_commit`

没有豁免文档，就没有例外。
