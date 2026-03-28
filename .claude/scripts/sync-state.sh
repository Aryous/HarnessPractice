#!/bin/bash
# 生成 Harness 单一状态文件
# 目标：把当前控制面压缩成主控可直接消费的 YAML 状态快照。

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/STATE.yaml"
TRACE_SCRIPT="$PROJECT_ROOT/.claude/scripts/trace.sh"

frontmatter_value() {
  local file="$1"
  local key="$2"

  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $0 ~ ("^" key ":") {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print $0
      exit
    }
  ' "$file"
}

count_questions() {
  local file="$1"
  grep -cE '^#{3,6} Q[0-9]+:' "$file" 2>/dev/null || true
}

count_decisions() {
  local file="$1"
  grep -cE '^\*\*裁决\*\*[:：]' "$file" 2>/dev/null || true
}

doc_exists() {
  local file="$1"
  [[ -f "$file" ]] && echo "true" || echo "false"
}

doc_status() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  frontmatter_value "$file" "status"
}

doc_open_questions() {
  local file="$1"
  [[ -f "$file" ]] || { echo "0"; return 0; }
  local value
  value="$(frontmatter_value "$file" "open_questions")"
  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "0"
  fi
}

doc_unresolved_questions() {
  local file="$1"
  [[ -f "$file" ]] || { echo "0"; return 0; }

  local questions decisions
  questions="$(count_questions "$file")"
  decisions="$(count_decisions "$file")"

  if [[ "$questions" =~ ^[0-9]+$ ]] && [[ "$decisions" =~ ^[0-9]+$ ]] && (( questions > decisions )); then
    echo $((questions - decisions))
  else
    echo "0"
  fi
}

doc_ready() {
  local file="$1"
  [[ -f "$file" ]] || { echo "false"; return 0; }

  local status open_questions unresolved
  status="$(doc_status "$file")"
  open_questions="$(doc_open_questions "$file")"
  unresolved="$(doc_unresolved_questions "$file")"

  if [[ "$status" == "approved" && "$open_questions" == "0" && "$unresolved" == "0" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

yaml_quote() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

intent_file="$PROJECT_ROOT/docs/product-specs/intent.md"
requirements_file="$PROJECT_ROOT/docs/product-specs/requirements.md"
architecture_file="$PROJECT_ROOT/.claude/ARCHITECTURE.md"
tech_decisions_file="$PROJECT_ROOT/docs/tech/tech-decisions.md"
design_spec_file="$PROJECT_ROOT/docs/design-docs/design-spec.md"

intent_exists="$(doc_exists "$intent_file")"
intent_status="$(doc_status "$intent_file")"
intent_ready="$(doc_ready "$intent_file")"
intent_open_questions="$(doc_open_questions "$intent_file")"
intent_unresolved="$(doc_unresolved_questions "$intent_file")"

requirements_exists="$(doc_exists "$requirements_file")"
requirements_status="$(doc_status "$requirements_file")"
requirements_ready="$(doc_ready "$requirements_file")"
requirements_open_questions="$(doc_open_questions "$requirements_file")"
requirements_unresolved="$(doc_unresolved_questions "$requirements_file")"

architecture_exists="$(doc_exists "$architecture_file")"
architecture_status="$(doc_status "$architecture_file")"
architecture_ready="$(doc_ready "$architecture_file")"
architecture_open_questions="$(doc_open_questions "$architecture_file")"
architecture_unresolved="$(doc_unresolved_questions "$architecture_file")"

tech_exists="$(doc_exists "$tech_decisions_file")"
tech_status="$(doc_status "$tech_decisions_file")"
tech_ready="$(doc_ready "$tech_decisions_file")"
tech_open_questions="$(doc_open_questions "$tech_decisions_file")"
tech_unresolved="$(doc_unresolved_questions "$tech_decisions_file")"

design_exists="$(doc_exists "$design_spec_file")"
design_status="$(doc_status "$design_spec_file")"
design_ready="$(doc_ready "$design_spec_file")"
design_open_questions="$(doc_open_questions "$design_spec_file")"
design_unresolved="$(doc_unresolved_questions "$design_spec_file")"

trace_coverage="unknown"
trace_missing="-1"
trace_ready="false"

if [[ -f "$TRACE_SCRIPT" ]]; then
  trace_output="$(bash "$TRACE_SCRIPT" 2>/dev/null || true)"
  parsed_coverage="$(echo "$trace_output" | sed -n 's/^  覆盖: \(.*\)$/\1/p' | tail -1)"
  parsed_missing="$(echo "$trace_output" | sed -n 's/^  缺失: \([0-9][0-9]*\)\/.*$/\1/p' | tail -1)"

  [[ -n "$parsed_coverage" ]] && trace_coverage="$parsed_coverage"
  if [[ -n "$parsed_missing" ]]; then
    trace_missing="$parsed_missing"
    [[ "$trace_missing" == "0" ]] && trace_ready="true"
  fi
fi

worktree_dirty_count="0"
worktree_clean="true"
if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  worktree_dirty_count="$(git -C "$PROJECT_ROOT" status --short | wc -l | tr -d ' ')"
  [[ "$worktree_dirty_count" == "0" ]] || worktree_clean="false"
fi

signals=()
warnings=()
blockers=()

add_signal() {
  signals+=("$1")
}

add_warning() {
  warnings+=("$1")
}

add_blocker() {
  blockers+=("$1")
}

[[ "$intent_ready" == "true" ]] && add_signal "intent_ready"
[[ "$requirements_ready" == "true" ]] && add_signal "requirements_ready"
[[ "$architecture_ready" == "true" ]] && add_signal "architecture_ready"
[[ "$tech_ready" == "true" ]] && add_signal "tech_decisions_ready"
[[ "$design_ready" == "true" ]] && add_signal "design_spec_ready"
[[ "$worktree_clean" == "true" ]] && add_signal "worktree_clean"
[[ "$trace_ready" == "true" ]] && add_signal "traceability_ready"

if [[ "$worktree_clean" != "true" ]]; then
  add_warning "worktree_dirty"
fi

if [[ "$trace_ready" != "true" ]]; then
  add_warning "traceability_open"
fi

if [[ "$requirements_exists" == "true" && "$requirements_ready" != "true" ]]; then
  if [[ "$requirements_status" == "review" || "$requirements_unresolved" != "0" || "$requirements_open_questions" != "0" ]]; then
    add_warning "requirements_waiting_review"
  fi
fi

if [[ "$architecture_exists" == "true" && "$architecture_ready" != "true" ]]; then
  add_warning "architecture_waiting_review"
fi

if [[ "$tech_exists" == "true" && "$tech_ready" != "true" ]]; then
  add_warning "tech_decisions_waiting_review"
fi

if [[ "$design_exists" == "true" && "$design_ready" != "true" ]]; then
  add_warning "design_spec_waiting_review"
fi

active_plan_count=0
ready_active_plan_count=0
waiting_active_plan_count=0
active_plan_entries=()

for file in "$PROJECT_ROOT"/docs/exec-plans/active/*.md; do
  [[ -f "$file" ]] || continue
  active_plan_count=$((active_plan_count + 1))

  plan_status="$(frontmatter_value "$file" "status")"
  plan_unresolved="$(doc_unresolved_questions "$file")"
  plan_ready="false"

  if [[ "$plan_status" == "approved" && "$plan_unresolved" == "0" ]]; then
    plan_ready="true"
    ready_active_plan_count=$((ready_active_plan_count + 1))
  else
    waiting_active_plan_count=$((waiting_active_plan_count + 1))
  fi

  active_plan_entries+=("$(basename "$file")|${file#$PROJECT_ROOT/}|${plan_status:-unknown}|$plan_unresolved|$plan_ready")
done

if (( ready_active_plan_count > 0 )); then
  add_signal "active_plan_ready"
fi

if (( waiting_active_plan_count > 0 )); then
  add_warning "active_plan_waiting_review"
fi

recommended_kind="human"
recommended_target="review"
recommended_reason="读取 .claude/STATE.yaml 后按当前阻塞项裁决。"

if [[ "$intent_exists" != "true" ]]; then
  recommended_target="intent"
  recommended_reason="缺少 intent.md，系统还没有可消费的起点。"
  add_blocker "intent_missing"
elif [[ "$intent_ready" != "true" ]]; then
  recommended_target="review"
  recommended_reason="intent.md 尚未 ready，先完成或审批意图文档。"
  add_blocker "intent_not_ready"
elif [[ "$requirements_exists" != "true" ]]; then
  recommended_kind="agent"
  recommended_target="req-review"
  recommended_reason="intent.md 已 ready，但 requirements.md 缺失。"
elif [[ "$requirements_ready" != "true" ]]; then
  recommended_target="review"
  recommended_reason="requirements.md 已存在但还不能被下游消费，先审阅或补齐裁决。"
  add_blocker "requirements_not_ready"
elif [[ "$architecture_exists" != "true" ]]; then
  recommended_kind="agent"
  recommended_target="architecture-bootstrap"
  recommended_reason="requirements.md 已 ready，但 .claude/ARCHITECTURE.md 缺失。"
elif [[ "$architecture_ready" != "true" ]]; then
  recommended_target="review"
  recommended_reason=".claude/ARCHITECTURE.md 已存在但还不能被下游消费。"
  add_blocker "architecture_not_ready"
elif [[ "$tech_exists" != "true" ]]; then
  recommended_kind="agent"
  recommended_target="tech-selection"
  recommended_reason="requirements 与 architecture 已 ready，但 tech-decisions.md 缺失。"
elif [[ "$tech_ready" != "true" ]]; then
  recommended_target="review"
  recommended_reason="tech-decisions.md 已存在但还不能被下游消费。"
  add_blocker "tech_decisions_not_ready"
elif [[ "$design_exists" != "true" ]]; then
  recommended_kind="agent"
  recommended_target="design"
  recommended_reason="上游文档已 ready，但 design-spec.md 缺失。"
elif [[ "$design_ready" != "true" ]]; then
  recommended_target="review"
  recommended_reason="design-spec.md 已存在但还不能被下游消费。"
  add_blocker "design_spec_not_ready"
elif (( ready_active_plan_count > 0 )); then
  recommended_kind="agent"
  recommended_target="feature"
  recommended_reason="存在 approved 且无未决 Q 的 active exec-plan，可进入实现。"
elif (( waiting_active_plan_count > 0 )); then
  recommended_target="review"
  recommended_reason="存在 active exec-plan，但尚未达到可执行状态。"
  add_blocker "active_plan_not_ready"
else
  recommended_target="plan"
  recommended_reason="上游已 ready，但当前没有可执行的 active exec-plan。"
fi

mkdir -p "$(dirname "$STATE_FILE")"
tmp_file="$(mktemp)"

{
  echo "version: 1"
  echo "generated_at: $(yaml_quote "$(date '+%F %T %z')")"
  echo "generated_by: $(yaml_quote ".claude/scripts/sync-state.sh")"
  echo "controller_should_read_first: true"
  echo "notes_file: $(yaml_quote ".claude/PIPELINE.md")"
  echo ""
  echo "docs:"
  echo "  intent:"
  echo "    path: $(yaml_quote "docs/product-specs/intent.md")"
  echo "    exists: $intent_exists"
  echo "    status: $(yaml_quote "${intent_status:-missing}")"
  echo "    ready: $intent_ready"
  echo "    open_questions: $intent_open_questions"
  echo "    unresolved_questions: $intent_unresolved"
  echo "  requirements:"
  echo "    path: $(yaml_quote "docs/product-specs/requirements.md")"
  echo "    exists: $requirements_exists"
  echo "    status: $(yaml_quote "${requirements_status:-missing}")"
  echo "    ready: $requirements_ready"
  echo "    open_questions: $requirements_open_questions"
  echo "    unresolved_questions: $requirements_unresolved"
  echo "  architecture:"
  echo "    path: $(yaml_quote ".claude/ARCHITECTURE.md")"
  echo "    exists: $architecture_exists"
  echo "    status: $(yaml_quote "${architecture_status:-missing}")"
  echo "    ready: $architecture_ready"
  echo "    open_questions: $architecture_open_questions"
  echo "    unresolved_questions: $architecture_unresolved"
  echo "  tech_decisions:"
  echo "    path: $(yaml_quote "docs/tech/tech-decisions.md")"
  echo "    exists: $tech_exists"
  echo "    status: $(yaml_quote "${tech_status:-missing}")"
  echo "    ready: $tech_ready"
  echo "    open_questions: $tech_open_questions"
  echo "    unresolved_questions: $tech_unresolved"
  echo "  design_spec:"
  echo "    path: $(yaml_quote "docs/design-docs/design-spec.md")"
  echo "    exists: $design_exists"
  echo "    status: $(yaml_quote "${design_status:-missing}")"
  echo "    ready: $design_ready"
  echo "    open_questions: $design_open_questions"
  echo "    unresolved_questions: $design_unresolved"
  echo ""
  if (( ${#active_plan_entries[@]} == 0 )); then
    echo "active_exec_plans: []"
  else
    echo "active_exec_plans:"
    for entry in "${active_plan_entries[@]}"; do
      IFS='|' read -r plan_name plan_path plan_status plan_unresolved plan_ready <<<"$entry"
      echo "  - name: $(yaml_quote "$plan_name")"
      echo "    path: $(yaml_quote "$plan_path")"
      echo "    status: $(yaml_quote "${plan_status:-unknown}")"
      echo "    unresolved_questions: $plan_unresolved"
      echo "    ready: $plan_ready"
    done
  fi
  echo ""
  echo "trace:"
  echo "  path: $(yaml_quote ".claude/scripts/trace.sh")"
  echo "  coverage: $(yaml_quote "$trace_coverage")"
  echo "  missing_count: $trace_missing"
  echo "  strict_ready: $trace_ready"
  echo ""
  echo "worktree:"
  echo "  dirty_count: $worktree_dirty_count"
  echo "  clean: $worktree_clean"
  echo ""
  if (( ${#signals[@]} == 0 )); then
    echo "signals: []"
  else
    echo "signals:"
    for signal in "${signals[@]}"; do
      echo "  - $(yaml_quote "$signal")"
    done
  fi
  echo ""
  if (( ${#warnings[@]} == 0 )); then
    echo "warnings: []"
  else
    echo "warnings:"
    for warning in "${warnings[@]}"; do
      echo "  - $(yaml_quote "$warning")"
    done
  fi
  echo ""
  if (( ${#blockers[@]} == 0 )); then
    echo "blockers: []"
  else
    echo "blockers:"
    for blocker in "${blockers[@]}"; do
      echo "  - $(yaml_quote "$blocker")"
    done
  fi
  echo ""
  echo "recommended_next:"
  echo "  kind: $(yaml_quote "$recommended_kind")"
  echo "  target: $(yaml_quote "$recommended_target")"
  echo "  reason: $(yaml_quote "$recommended_reason")"
} >"$tmp_file"

mv "$tmp_file" "$STATE_FILE"
echo "$STATE_FILE"
