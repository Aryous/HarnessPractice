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

bash "$CLOSEOUT" "${CLOSEOUT_ARGS[@]}"
git -C "$PROJECT_ROOT" commit "${GIT_ARGS[@]}"
