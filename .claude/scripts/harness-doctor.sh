#!/bin/bash
# Harness 会话健康检查
# 用于新会话启动时快速判断：当前仓库是否具备继续推进的最小条件。

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_SCRIPT="$PROJECT_ROOT/.claude/scripts/sync-state.sh"
STATE_FILE="$PROJECT_ROOT/.claude/STATE.yaml"
STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

BLOCKERS=0
WARNINGS=0

ok() {
  echo "  ✅ $1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  echo "  ⚠️  $1"
}

block() {
  BLOCKERS=$((BLOCKERS + 1))
  echo "  ❌ $1"
}

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

check_required_file() {
  local file="$1"
  local label="$2"

  if [[ -f "$file" ]]; then
    ok "$label 存在"
  else
    block "$label 缺失：${file#$PROJECT_ROOT/}"
  fi
}

check_architecture_doc() {
  local file="$PROJECT_ROOT/.claude/ARCHITECTURE.md"
  local requirements="$PROJECT_ROOT/docs/product-specs/requirements.md"
  local req_status=""

  if [[ -f "$requirements" ]]; then
    req_status="$(frontmatter_value "$requirements" "status")"
  fi

  if [[ ! -f "$file" ]]; then
    if [[ "$req_status" == "approved" ]]; then
      block ".claude/ARCHITECTURE.md 缺失：先运行 architecture-bootstrap 生成架构契约"
    else
      warn ".claude/ARCHITECTURE.md 尚未创建：待 requirements.md approved 后运行 architecture-bootstrap"
    fi
    return
  fi

  ok ".claude/ARCHITECTURE.md 存在"
}

check_status_doc() {
  local file="$1"
  local label="$2"
  local must_be_approved="${3:-false}"

  if [[ ! -f "$file" ]]; then
    block "$label 缺失：${file#$PROJECT_ROOT/}"
    return
  fi

  local status
  status="$(frontmatter_value "$file" "status")"
  local open_questions
  open_questions="$(frontmatter_value "$file" "open_questions")"
  local question_count
  question_count="$(count_questions "$file")"
  local decision_count
  decision_count="$(count_decisions "$file")"
  local unresolved=0

  if [[ "$question_count" =~ ^[0-9]+$ ]] && [[ "$decision_count" =~ ^[0-9]+$ ]] && (( question_count > decision_count )); then
    unresolved=$((question_count - decision_count))
  fi

  if [[ -z "$status" ]]; then
    warn "$label 缺少 frontmatter status"
  else
    ok "$label 状态：$status"
  fi

  if [[ "$must_be_approved" == "true" && "$status" != "approved" ]]; then
    block "$label 尚未 approved（当前：${status:-unknown}）"
  fi

  if [[ "$status" == "approved" && -n "$open_questions" && "$open_questions" != "0" ]]; then
    block "$label 标记为 approved，但 open_questions=${open_questions}"
  elif [[ -n "$open_questions" && "$open_questions" != "0" ]]; then
    warn "$label 仍有 open_questions=${open_questions}"
  fi

  if [[ "$status" == "approved" && "$unresolved" != "0" ]]; then
    block "$label 标记为 approved，但仍有 ${unresolved} 个未决 Q"
  elif [[ "$unresolved" != "0" ]]; then
    warn "$label 仍有 ${unresolved} 个未决 Q"
  fi
}

echo "═══════════════════════════════════════════════"
echo "  Harness Doctor"
echo "  根目录: $PROJECT_ROOT"
echo "═══════════════════════════════════════════════"
echo ""

echo "项目与主控文件"
check_required_file "$PROJECT_ROOT/CLAUDE.md" "CLAUDE.md"
check_required_file "$PROJECT_ROOT/.claude/project.md" ".claude/project.md"
check_required_file "$STATE_SCRIPT" ".claude/scripts/sync-state.sh"
if [[ -f "$PROJECT_ROOT/.claude/PIPELINE.md" ]]; then
  ok ".claude/PIPELINE.md 存在（人工备注）"
else
  warn ".claude/PIPELINE.md 缺失（仅影响人工备注，不影响实时状态）"
fi
echo ""

echo "上游真相源"
check_status_doc "$PROJECT_ROOT/docs/product-specs/requirements.md" "requirements.md" "true"
check_architecture_doc
check_status_doc "$PROJECT_ROOT/docs/tech/tech-decisions.md" "tech-decisions.md" "true"
check_status_doc "$PROJECT_ROOT/docs/design-docs/design-spec.md" "design-spec.md" "true"
echo ""

echo "活跃执行计划"
active_plans=("$PROJECT_ROOT"/docs/exec-plans/active/*.md)
if (( ${#active_plans[@]} == 0 )); then
  warn "当前没有 active exec-plan"
else
  for file in "${active_plans[@]}"; do
    base="$(basename "$file")"
    status="$(frontmatter_value "$file" "status")"
    questions="$(count_questions "$file")"
    decisions="$(count_decisions "$file")"
    unresolved=0
    if [[ "$questions" =~ ^[0-9]+$ ]] && [[ "$decisions" =~ ^[0-9]+$ ]] && (( questions > decisions )); then
      unresolved=$((questions - decisions))
    fi

    if [[ -z "$status" ]]; then
      warn "active plan $base 缺少 status"
    else
      ok "active plan $base 状态：$status"
    fi

    if [[ "$status" == "approved" && "$unresolved" != "0" ]]; then
      block "active plan $base 标记为 approved，但仍有 ${unresolved} 个未决 Q"
    elif [[ "$unresolved" != "0" ]]; then
      warn "active plan $base 仍有 ${unresolved} 个未决 Q"
    fi
  done
fi
echo ""

echo "Git 与 Hook"
if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  hooks_path="$(git -C "$PROJECT_ROOT" config --get core.hooksPath || true)"
  if [[ "$hooks_path" == ".githooks" ]]; then
    ok "git hooksPath=.githooks"
  else
    warn "git hooksPath 当前为 ${hooks_path:-unset}"
  fi

  if [[ -f "$PROJECT_ROOT/.githooks/pre-commit" ]]; then
    ok "pre-commit hook 存在"
  else
    warn "缺少 .githooks/pre-commit"
  fi

  dirty_count="$(git -C "$PROJECT_ROOT" status --short | wc -l | tr -d ' ')"
  if [[ "$dirty_count" == "0" ]]; then
    ok "worktree 干净"
  else
    warn "worktree 有 ${dirty_count} 条未提交变更"
  fi
else
  warn "当前目录不是 git 仓库"
fi
echo ""

echo "溯源与验证"
if [[ -f "$PROJECT_ROOT/.claude/scripts/trace.sh" ]]; then
  trace_output="$(bash "$PROJECT_ROOT/.claude/scripts/trace.sh")"
  coverage_line="$(echo "$trace_output" | sed -n 's/^  覆盖: \(.*\)$/\1/p' | tail -1)"
  missing_count="$(echo "$trace_output" | sed -n 's/^  缺失: \([0-9][0-9]*\)\/.*$/\1/p' | tail -1)"

  if [[ -n "$missing_count" && "$missing_count" != "0" ]]; then
    if $STRICT; then
      block "traceability 未闭合：${coverage_line:-unknown}"
    else
      warn "traceability 未闭合：${coverage_line:-unknown}"
    fi
  else
    ok "traceability 已闭合：${coverage_line:-unknown}"
  fi
else
  block "缺少 .claude/scripts/trace.sh"
fi
echo ""

echo "状态文件"
if [[ -f "$STATE_SCRIPT" ]]; then
  if bash "$STATE_SCRIPT" >/dev/null; then
    ok "STATE 已刷新：${STATE_FILE#$PROJECT_ROOT/}"
    if [[ -f "$STATE_FILE" ]]; then
      state_kind="$(awk '/^recommended_next:/{flag=1; next} flag && /^  kind:/{sub(/^  kind: /, "", $0); gsub(/"/, "", $0); print; exit}' "$STATE_FILE")"
      state_target="$(awk '/^recommended_next:/{flag=1; next} flag && /^  target:/{sub(/^  target: /, "", $0); gsub(/"/, "", $0); print; exit}' "$STATE_FILE")"
      state_reason="$(awk '/^recommended_next:/{flag=1; next} flag && /^  reason:/{sub(/^  reason: /, "", $0); gsub(/"/, "", $0); print; exit}' "$STATE_FILE")"
      if [[ -n "$state_target" ]]; then
        ok "推荐下一步：${state_kind:-unknown} / ${state_target} — ${state_reason:-无}"
      fi
    fi
  else
    block "STATE 刷新失败"
  fi
else
  block "缺少 .claude/scripts/sync-state.sh"
fi
echo ""

echo "───────────────────────────────────────────────"
echo "  Blockers: $BLOCKERS"
echo "  Warnings: $WARNINGS"
echo "───────────────────────────────────────────────"

if $STRICT && (( BLOCKERS > 0 )); then
  exit 1
fi
