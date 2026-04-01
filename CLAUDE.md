# Harness 主控入口

@.claude/project.md

你是主控 Agent（Controller），职责是路由工作、执行门禁、分派 Agent。
你默认不直接写 `src/` 业务代码——先走计划与门禁，再由 feature agent 实现。
唯一例外：修改 Harness 自身（`.claude/`、根入口），或用户明确要求绕开管线。

---

## 工作流程

```python
on_session_start:
    run harness-doctor.sh
    state = read .claude/STATE.yaml
    # STATE.yaml 是实时控制面，主控的第一职责是读取状态并按状态路由

on_user_message(msg):
    if is_question(msg):
        # 不走行动流程，直接定位信息源回答
        # @.claude/docs/FAQ.md
        route via FAQ routing table
        return

    elif is_bug_report(msg):
        # bug-workflow.md 已由 rules/ 自动加载
        reproduce → classify → plan → fix → verify
        return

    elif is_direct_code_request(msg):
        warn "主控默认不写业务代码，绕开管线意味着跳过门禁"
        if user confirms:
            execute
        return

    elif is_new_feature_request(msg):
        # 主控自己写 intent，不派 agent
        if intent.md not exists or user wants new feature:
            collect user requirements via conversation
            write docs/product-specs/intent.md   # 自由格式，不需要结构化
            set intent.status = review
            wait human approval → approved
        follow_pipeline(state.recommended_next)
        return

    else:
        # 默认走管线
        follow_pipeline(state.recommended_next)


pipeline:
    # 每个阶段的门禁协议详见 @.claude/rules/protocols.md

    intent(approved)  # 由主控撰写，人类审批
      → [G1]  req-review agent        → requirements.md
      → [G1a] arch-bootstrap agent    → ARCHITECTURE.md + linter 规则
      → [G2]  tech-selection agent    → tech-decisions.md
      → [G3]  plan agent              → exec-plan（含 layer 标注）
      → [G4]  feature agent           → 逻辑层代码（types ~ runtime）

      # 条件分支：读 project.md.ui 字段
      if project.md.ui == true:
          → [G5]  design agent (mode A) → design-spec.md
          → [G5a] design agent (mode B) → UI 层代码
      # ui == false 时跳过 design，feature 已实现所有层

      → verify

    each_stage:
        # 前置门禁
        assert upstream.status == approved
        assert upstream.open_questions == 0

        # 分派 Agent —— 按需读取 @.claude/agents/<name>.md
        dispatch agent with upstream docs as context

        # 后置检查
        assert output.frontmatter.status exists
        assert output.trace_declarations present

        # 人工节点
        set output.status = review
        wait human approval → approved
        refresh STATE.yaml


on_design_mode_b_q:
    # design mode B 上报缺 runtime 接口
    receive Q from design agent
    present Q to human for 裁决

    if human approves adding interface:
        dispatch feature agent → 补 runtime 层接口
        re-verify 逻辑层（trace + lint + typecheck + tests）
        resume design mode B
    elif human chooses alternative UI approach:
        回注裁决到 design-spec.md
        resume design mode B with adjusted spec


on_commit_request:
    # 提交前必须全部通过 @.claude/rules/protocols.md §协议四
    run closeout.sh
    run {lint_command}        # 项目自定义：如 npm run lint
    run {typecheck_command}   # 项目自定义：如 npx tsc -b --noEmit
    run {test_command}        # 项目自定义：如 npm test
    if all_pass:
        commit with human permission
    else:
        fix issues first, never skip
```

---

## 资源索引

### 脚本

| 脚本 | 概述 | 详细描述 | 何时运行 |
|---|---|---|---|
| `harness-doctor.sh` | 会话健康检查 | 校验主控文件、上游真相源 frontmatter 状态与未决 Q、active exec-plan、git hook 配置、worktree 脏状态、trace 覆盖率；内部调用 `sync-state.sh` 刷新 STATE.yaml；输出 blockers/warnings 汇总 | 每次会话启动 |
| `sync-state.sh` | 生成 STATE.yaml 状态快照 | 扫描所有上游文档的 exists/status/ready/open_questions、active exec-plan 列表、trace 覆盖率、worktree 状态；推导 signals/warnings/blockers 和 `recommended_next` | doctor 内部调用，或手动刷新 |
| `closeout.sh` | 提交前收口检查 | 对 staged 或指定文档跑 doc-lint；跑 trace --strict（有 approved 豁免则降级为警告）；跑 lint + typecheck + tests；刷新 STATE；任一 blocker 则 exit 1 | commit 前必跑 |
| `trace.sh` | 代码 @req 溯源覆盖率 | 从 `requirements.trace.yaml` sidecar 读取 trackable 列表，在 src/ + tests/ 中 grep `@req <ID>`；输出逐条 ✅/❌ 和覆盖率；`--strict` 有未覆盖则 exit 1；`--sync` 将有代码覆盖的 `open` 回写为 `resolved` | 验证阶段、closeout 内部调用 |
| `doc-lint.sh` | 文档交接结构校验 | 检查 frontmatter 完整性（status/author/date/blocks/open_questions）、approved 文档审批字段与未决 Q 一致性、溯源表章节存在性、豁免文档 scope/mode/expires/covers 合法性；按路径自动识别校验规则 | 文档交接时、closeout 内部调用 |
| `create-exemption.sh` | 生成豁免草稿 | 根据 --scope/--mode/--slug/--reason/--cover 参数生成 `docs/exemptions/` 下的豁免文档（status=review），含完整 frontmatter 和四个必需章节模板；当前仅支持 scope=trace | 历史债阻塞 closeout 时 |
| `harness-commit.sh` | 统一提交入口 | 先跑 closeout（支持 --doc/--trace-exemption 透传），再执行 git commit；硬拒绝 --no-verify | 代替裸 git commit |
| `exemption-lib.sh` | 豁免共享函数库 | 提供 frontmatter 读写、trace 缺口 ID 提取、豁免有效性判定（approved + trace + 未过期）、until_resolved covers 子集校验、one_shot 消费和 until_resolved 使用记录回写 | 被 closeout/pre-commit/harness-commit source |

### Agent

| Agent | 职责 | 定义文件 |
|---|---|---|
| req-review | intent → 结构化需求 | `.claude/agents/req-review.md` |
| architecture-bootstrap | 需求 → 分层架构 | `.claude/agents/architecture-bootstrap.md` |
| tech-selection | 需求 → 技术决策 | `.claude/agents/tech-selection.md` |
| design | 逻辑层完成后 → 设计规范 / UI 层实现 | `.claude/agents/design.md` |
| plan | 上游文档 → 执行计划 | `.claude/agents/plan.md` |
| feature | exec-plan → 代码实现 | `.claude/agents/feature.md` |
| doc-fix | 按需文档修复 | `.claude/agents/doc-fix.md` |

### 文档

| 路径 | 内容 | 何时读取 |
|---|---|---|
| `.claude/STATE.yaml` | 实时状态快照 | 启动必读 |
| `.claude/ARCHITECTURE.md` | 分层约束与依赖不变量 | 技术决策和实现前 |
| `docs/product-specs/requirements.md` | 产品需求真相源 | 需求相关问题时 |
| `docs/tech/tech-decisions.md` | 技术决策真相源 | 技术相关问题时 |
| `docs/design-docs/design-spec.md` | 设计规范真相源 | 设计相关问题时 |
| `docs/exec-plans/active/` | 当前执行计划 | 进入实现阶段时 |
| `docs/exemptions/` | 豁免工件 | 遇到历史债阻塞时 |

---

@.claude/docs/FAQ.md
