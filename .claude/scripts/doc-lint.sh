#!/bin/bash
# 文档交接检查
# 用于机械化校验 Harness 关键文档是否满足最小交接结构。

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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

has_frontmatter() {
  local file="$1"
  [[ "$(head -n 1 "$file" 2>/dev/null || true)" == "---" ]]
}

count_questions() {
  local file="$1"
  grep -cE '^#{3,6} Q[0-9]+:' "$file" 2>/dev/null || true
}

count_decisions() {
  local file="$1"
  grep -cE '^\*\*裁决\*\*[:：]' "$file" 2>/dev/null || true
}

require_section() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -qE "$pattern" "$file"; then
    ok "$label"
  else
    block "$label 缺失：${file#$PROJECT_ROOT/}"
  fi
}

validate_exemption_doc() {
  local file="$1"
  local rel="${file#$PROJECT_ROOT/}"
  local status scope mode expires approved_by approved_date consumed_by_commit consumed_date today
  local covers

  status="$(frontmatter_value "$file" "status")"
  scope="$(frontmatter_value "$file" "scope")"
  mode="$(frontmatter_value "$file" "mode")"
  expires="$(frontmatter_value "$file" "expires")"
  approved_by="$(frontmatter_value "$file" "approved_by")"
  approved_date="$(frontmatter_value "$file" "approved_date")"
  consumed_by_commit="$(frontmatter_value "$file" "consumed_by_commit")"
  consumed_date="$(frontmatter_value "$file" "consumed_date")"
  covers="$(frontmatter_value "$file" "covers")"
  today="$(date +%F)"

  case "$status" in
    draft|review|approved|consumed|expired|revoked)
      ok "$rel status=$status"
      ;;
    *)
      block "$rel status 非法：$status"
      ;;
  esac

  if [[ -z "$scope" ]]; then
    block "$rel 缺少 scope"
  else
    ok "$rel scope=$scope"
  fi

  case "$mode" in
    one_shot|until_resolved)
      ok "$rel mode=$mode"
      ;;
    *)
      block "$rel mode 非法：$mode"
      ;;
  esac

  if [[ -z "$expires" ]]; then
    block "$rel 缺少 expires"
  elif [[ "$expires" < "$today" ]]; then
    if [[ "$status" == "approved" ]]; then
      block "$rel approved 豁免已过期（expires=$expires）"
    else
      ok "$rel 已过期（status=$status）"
    fi
  else
    ok "$rel 未过期"
  fi

  if [[ "$status" == "approved" || "$status" == "consumed" || "$status" == "revoked" ]]; then
    if [[ -z "$approved_by" || -z "$approved_date" ]]; then
      block "$rel 缺少 approved_by / approved_date"
    else
      ok "$rel 审批信息完整"
    fi
  fi

  if [[ "$mode" == "until_resolved" ]]; then
    if [[ -z "${covers//[[:space:]]/}" || "$covers" == "[]" ]]; then
      block "$rel until_resolved 豁免必须声明 covers"
    else
      ok "$rel covers 已声明"
    fi
  fi

  if [[ "$status" == "consumed" ]]; then
    if [[ -z "$consumed_by_commit" || -z "$consumed_date" ]]; then
      block "$rel consumed 豁免缺少 consumed_by_commit / consumed_date"
    else
      ok "$rel consumed 信息完整"
    fi
  fi

  require_section "$file" '^## 背景$' "$rel 背景章节"
  require_section "$file" '^## 允许跳过$' "$rel 允许跳过章节"
  require_section "$file" '^## 约束$' "$rel 约束章节"
  require_section "$file" '^## 退出条件$' "$rel 退出条件章节"
}

validate_agent_output_doc() {
  local file="$1"
  local rel="${file#$PROJECT_ROOT/}"
  local status author date blocks open_questions questions decisions unresolved

  if [[ ! -f "$file" ]]; then
    block "文件不存在：$rel"
    return
  fi

  if has_frontmatter "$file"; then
    ok "$rel frontmatter 存在"
  else
    block "$rel 缺少 YAML frontmatter"
    return
  fi

  status="$(frontmatter_value "$file" "status")"
  author="$(frontmatter_value "$file" "author")"
  date="$(frontmatter_value "$file" "date")"
  blocks="$(frontmatter_value "$file" "blocks")"
  open_questions="$(frontmatter_value "$file" "open_questions")"
  questions="$(count_questions "$file")"
  decisions="$(count_decisions "$file")"
  unresolved=0

  if [[ "$questions" =~ ^[0-9]+$ ]] && [[ "$decisions" =~ ^[0-9]+$ ]] && (( questions > decisions )); then
    unresolved=$((questions - decisions))
  fi

  [[ -n "$status" ]] && ok "$rel status=$status" || block "$rel 缺少 status"
  [[ -n "$author" ]] && ok "$rel author=$author" || block "$rel 缺少 author"
  [[ -n "$date" ]] && ok "$rel date=$date" || block "$rel 缺少 date"
  [[ -n "$blocks" ]] && ok "$rel blocks 存在" || block "$rel 缺少 blocks"
  [[ -n "$open_questions" ]] && ok "$rel open_questions=$open_questions" || block "$rel 缺少 open_questions"

  if [[ "$status" == "approved" ]]; then
    local approved_by approved_date
    approved_by="$(frontmatter_value "$file" "approved_by")"
    approved_date="$(frontmatter_value "$file" "approved_date")"

    [[ "$open_questions" == "0" ]] || block "$rel approved 文档必须满足 open_questions: 0"
    [[ -n "$approved_by" ]] && ok "$rel approved_by=$approved_by" || block "$rel approved 文档缺少 approved_by"
    [[ -n "$approved_date" ]] && ok "$rel approved_date=$approved_date" || block "$rel approved 文档缺少 approved_date"
    (( unresolved == 0 )) || block "$rel approved 文档仍有 ${unresolved} 个未决 Q"
  elif (( unresolved > 0 )); then
    warn "$rel 仍有 ${unresolved} 个未决 Q"
  fi
}

validate_trace_table_doc() {
  local file="$1"
  local rel="${file#$PROJECT_ROOT/}"

  require_section "$file" '^## 溯源表$' "$rel 溯源表章节"
  require_section "$file" '^\| 输入条目 \| 处理 \| 输出位置 \| 备注 \|$' "$rel 溯源表表头"
}

validate_file() {
  local file="$1"

  case "$file" in
    "$PROJECT_ROOT/docs/exemptions/template.md"|"$PROJECT_ROOT/docs/exec-plans/template.md")
      warn "模板文件跳过正式交接校验：${file#$PROJECT_ROOT/}"
      return
      ;;
    "$PROJECT_ROOT/.claude/ARCHITECTURE.md"|\
    "$PROJECT_ROOT/docs/tech/tech-decisions.md"|\
    "$PROJECT_ROOT/docs/design-docs/design-spec.md"|\
    "$PROJECT_ROOT/docs/product-specs/requirements.md"|\
    "$PROJECT_ROOT"/docs/exec-plans/active/*.md|\
    "$PROJECT_ROOT"/docs/exec-plans/completed/*.md)
      validate_agent_output_doc "$file"
      ;;
    "$PROJECT_ROOT"/docs/exemptions/*.md)
      validate_exemption_doc "$file"
      ;;
    *)
      warn "未定义校验规则，跳过：${file#$PROJECT_ROOT/}"
      return
      ;;
  esac

  case "$file" in
    "$PROJECT_ROOT/.claude/ARCHITECTURE.md")
      require_section "$file" '^## 域分层模型$' "${file#$PROJECT_ROOT/} 域分层模型章节"
      require_section "$file" '^## 依赖规则$' "${file#$PROJECT_ROOT/} 依赖规则章节"
      require_section "$file" '^## 目录结构映射$' "${file#$PROJECT_ROOT/} 目录结构映射章节"
      validate_trace_table_doc "$file"
      ;;
    "$PROJECT_ROOT/docs/tech/tech-decisions.md")
      require_section "$file" '^## 已裁决问题$' "${file#$PROJECT_ROOT/} 已裁决问题章节"
      validate_trace_table_doc "$file"
      ;;
    "$PROJECT_ROOT"/docs/exec-plans/active/*.md|"$PROJECT_ROOT"/docs/exec-plans/completed/*.md)
      require_section "$file" '^## 验收标准$' "${file#$PROJECT_ROOT/} 验收标准章节"
      validate_trace_table_doc "$file"
      ;;
  esac
}

collect_changed_targets() {
  git -C "$PROJECT_ROOT" status --short 2>/dev/null | awk '{print $2}' | while read -r path; do
    case "$path" in
      .claude/ARCHITECTURE.md|docs/tech/tech-decisions.md|docs/exec-plans/active/*.md|docs/exec-plans/completed/*.md|docs/exemptions/*.md)
        echo "$PROJECT_ROOT/$path"
        ;;
    esac
  done
}

TARGETS=()

if (( $# == 0 )); then
  while IFS= read -r file; do
    [[ -n "$file" ]] && TARGETS+=("$file")
  done < <(collect_changed_targets)
else
  for arg in "$@"; do
    if [[ "$arg" = /* ]]; then
      TARGETS+=("$arg")
    else
      TARGETS+=("$PROJECT_ROOT/$arg")
    fi
  done
fi

if (( ${#TARGETS[@]} == 0 )); then
  echo "未找到需要校验的关键文档。"
  echo "用法: bash .claude/scripts/doc-lint.sh <file> [file...]"
  exit 1
fi

echo "═══════════════════════════════════════════════"
echo "  Doc Lint"
echo "═══════════════════════════════════════════════"
echo ""

for file in "${TARGETS[@]}"; do
  validate_file "$file"
done

echo ""
echo "───────────────────────────────────────────────"
echo "  Blockers: $BLOCKERS"
echo "  Warnings: $WARNINGS"
echo "───────────────────────────────────────────────"

if (( BLOCKERS > 0 )); then
  exit 1
fi
