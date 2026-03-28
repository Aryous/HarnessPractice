#!/bin/bash
# 豁免脚手架
# 用于在 closeout 被历史债阻塞时，快速生成一份待审批的豁免文档草稿。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCOPE=""
MODE="one_shot"
SLUG=""
REASON=""
TITLE=""
PATHS=()
COVERS=()

usage() {
  cat <<'EOF'
用法:
  bash .claude/scripts/create-exemption.sh \
    --scope trace \
    --mode until_resolved \
    --slug f05-ai-zod \
    --reason "历史 trace 债阻塞当前修复提交" \
    --cover F06 \
    --cover F07 \
    --path docs/exec-plans/completed/bugfix-ai-zod-validation.md

参数:
  --scope   豁免 scope（当前仅支持 trace）
  --mode    one_shot | until_resolved（默认 one_shot）
  --slug    文件名后缀，建议使用短横线 slug
  --reason  一句话说明豁免原因
  --title   可选，自定义标题
  --cover   可重复，记录 until_resolved 覆盖的历史缺口 ID
  --path    可重复，记录本次受影响的计划/文档路径
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --scope)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --scope 参数"; exit 1; }
      SCOPE="$1"
      ;;
    --mode)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --mode 参数"; exit 1; }
      MODE="$1"
      ;;
    --slug)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --slug 参数"; exit 1; }
      SLUG="$1"
      ;;
    --reason)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --reason 参数"; exit 1; }
      REASON="$1"
      ;;
    --title)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --title 参数"; exit 1; }
      TITLE="$1"
      ;;
    --path)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --path 参数"; exit 1; }
      PATHS+=("$1")
      ;;
    --cover)
      shift
      [[ $# -gt 0 ]] || { echo "缺少 --cover 参数"; exit 1; }
      COVERS+=("$1")
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

[[ -n "$SCOPE" ]] || { echo "缺少 --scope"; usage; exit 1; }
[[ -n "$SLUG" ]] || { echo "缺少 --slug"; usage; exit 1; }
[[ -n "$REASON" ]] || { echo "缺少 --reason"; usage; exit 1; }

if [[ "$SCOPE" != "trace" ]]; then
  echo "当前仅支持 trace scope。"
  exit 1
fi

if [[ "$MODE" != "one_shot" && "$MODE" != "until_resolved" ]]; then
  echo "mode 只能是 one_shot 或 until_resolved。"
  exit 1
fi

if [[ "$MODE" == "until_resolved" && ${#COVERS[@]} -eq 0 ]]; then
  echo "until_resolved 模式必须至少提供一个 --cover。"
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="$SCOPE 豁免 — $SLUG"
fi

FILE="$PROJECT_ROOT/docs/exemptions/$(date +%F)-${SCOPE}-${SLUG}.md"

if [[ -e "$FILE" ]]; then
  echo "文件已存在：${FILE#$PROJECT_ROOT/}"
  exit 1
fi

mkdir -p "$(dirname "$FILE")"

paths_yaml=""
if (( ${#PATHS[@]} > 0 )); then
  for path in "${PATHS[@]}"; do
    paths_yaml+="${path}, "
  done
  paths_yaml="${paths_yaml%, }"
else
  paths_yaml="[请填写本次受影响的计划或文档路径]"
fi

covers_yaml=""
if (( ${#COVERS[@]} > 0 )); then
  for cover in "${COVERS[@]}"; do
    covers_yaml+="${cover}, "
  done
  covers_yaml="${covers_yaml%, }"
else
  covers_yaml=""
fi

cat > "$FILE" <<EOF
---
status: review
scope: $SCOPE
mode: $MODE
reason: $REASON
approved_by:
approved_date:
expires: YYYY-MM-DD
covers: [$covers_yaml]
consumed_by_commit:
consumed_date:
last_used_commit:
last_used_date:
paths: [$paths_yaml]
---

# 豁免：$TITLE

## 背景

- 当前变更已完成局部修复，但被仓库级历史 $SCOPE 门禁债阻塞
- 本次阻塞不由当前变更引入，请在这里补充具体上下文

## 允许跳过

- $SCOPE --strict 的严格阻断
- 仅允许本次变更在其余门禁通过时继续提交

## 约束

- 不得扩大本次变更范围来顺手夹带其他未完成工作
- 必须保留原始失败报告，不能宣称“全部验证通过”
- lint / typecheck / tests / 文档交接仍必须全部通过

## 退出条件

- 对应历史债已补齐，$SCOPE 可重新严格通过
- 本豁免文档已删除或显式失效
EOF

echo "已创建豁免草稿：${FILE#$PROJECT_ROOT/}"
echo "下一步：补齐 expires / 背景 / 约束，并由人类审批后再重跑 closeout。"
