# Harness Practice

Agent 驱动的软件工程框架——从需求到代码的全链路管线。

## 核心理念

- **管线即门禁**：intent → requirements → architecture → tech-decisions → design → plan → code，每个阶段有明确的准入/准出条件
- **Agent 各司其职**：7 个 Agent 角色，每个有独立的职责边界和输出契约（Skill）
- **文档即状态**：所有决策写入文档，口头结论不算落库
- **Sidecar 溯源**：结构化追踪数据与文档正文解耦，脚本读 YAML 不 scrape Markdown
- **豁免即工件**：历史债不能口头跳过，必须有受控的豁免文档和生命周期

## 快速开始

1. 编辑 `.claude/project.md`，填入项目名称和目标
2. 编辑 `CLAUDE.md` 中的 `{lint_command}` / `{typecheck_command}` / `{test_command}` 占位符
3. 告诉主控你的需求，它会引导你走完整个管线

## 目录结构

```
.claude/
  agents/         7 个 Agent 定义
  skills/         5 个输出契约 Skill
  scripts/        8 个管线脚本
  rules/          3 个系统规则
  docs/           FAQ 路由表
  project.md      项目配置（用户填写）
  STATE.yaml      实时状态（脚本生成）
  ARCHITECTURE.md 分层架构（agent 生成）

docs/
  product-specs/  intent.md + requirements.md + sidecar
  design-docs/    design-spec.md + sidecar
  tech/           tech-decisions.md + sidecar
  exec-plans/     active/ + completed/ + template
  exemptions/     豁免工件

CLAUDE.md         主控入口
```

## 管线流程

```
intent(approved)
  → [G1]  req-review        → requirements.md
  → [G1a] arch-bootstrap    → ARCHITECTURE.md
  → [G2]  tech-selection    → tech-decisions.md
  → [G3]  design (阶段A)    → design-spec.md
  → [G4]  plan              → exec-plan
  → [G5]  feature           → code
  → verify
```

## 来源

从 [墨简 (Mojian)](https://github.com/Aryous/Mojian) 项目抽象而来。
