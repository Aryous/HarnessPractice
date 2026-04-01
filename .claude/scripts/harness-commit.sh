#!/bin/bash
# 统一提交入口
# 先跑 closeout，再执行 git commit。禁止把 --no-verify 当作正常路径。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLOSEOUT="$PROJECT_ROOT/.claude/scripts/closeout.sh"
GIT_ARGS=()
CLOSEOUT_ARGS=()

usage() {
  cat <<'EOF'
用法:
  bash .claude/scripts/harness-commit.sh \
    --doc docs/tech/tech-decisions.md \
    --doc docs/exec-plans/completed/bugfix-ai-zod-validation.md \
    -- -m "feat: message"

说明:
  - `--doc` / `--trace-exemption` 会传给 closeout.sh
  - `--` 之后的参数会原样传给 `git commit`
  - 禁止使用 `--no-verify`
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --doc|--trace-exemption)
      flag="$1"
      shift
      [[ $# -gt 0 ]] || { echo "缺少 ${flag} 参数"; exit 1; }
      CLOSEOUT_ARGS+=("$flag" "$1")
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while (( $# > 0 )); do
        if [[ "$1" == "--no-verify" ]]; then
          echo "禁止使用 git commit --no-verify。若被历史债阻塞，请先创建并审批 docs/exemptions/*.md。"
          exit 1
        fi
        GIT_ARGS+=("$1")
        shift
      done
      break
      ;;
    *)
      if [[ "$1" == "--no-verify" ]]; then
        echo "禁止使用 git commit --no-verify。若被历史债阻塞，请先创建并审批 docs/exemptions/*.md。"
        exit 1
      fi
      GIT_ARGS+=("$1")
      ;;
  esac
  shift
done

if (( ${#GIT_ARGS[@]} == 0 )); then
  echo "缺少 git commit 参数。"
  usage
  exit 1
fi

EXEMPTION_LIB="$PROJECT_ROOT/.claude/scripts/exemption-lib.sh"
USED_EXEMPTION_FILE="$(mktemp)"
export HARNESS_USED_EXEMPTION_FILE="$USED_EXEMPTION_FILE"

if (( ${#CLOSEOUT_ARGS[@]} > 0 )); then
  bash "$CLOSEOUT" "${CLOSEOUT_ARGS[@]}"
else
  bash "$CLOSEOUT"
fi
git -C "$PROJECT_ROOT" commit "${GIT_ARGS[@]}"

# 提交成功后，推进豁免状态（协议七要求脚本自动完成，不依赖 Agent）
# 仅消费 closeout 实际使用的豁免，不盲目消费所有 approved 豁免
COMMIT_SHA="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
if [[ -f "$EXEMPTION_LIB" && -s "$USED_EXEMPTION_FILE" ]]; then
  source "$EXEMPTION_LIB"
  while IFS= read -r exemption_file; do
    [[ -f "$exemption_file" ]] || continue
    ex_mode="$(frontmatter_value "$exemption_file" "mode")"
    if [[ "$ex_mode" == "one_shot" ]]; then
      mark_exemption_consumed "$exemption_file" "$COMMIT_SHA"
    elif [[ "$ex_mode" == "until_resolved" ]]; then
      record_exemption_usage "$exemption_file" "$COMMIT_SHA"
    fi
  done < "$USED_EXEMPTION_FILE"
fi
rm -f "$USED_EXEMPTION_FILE"
