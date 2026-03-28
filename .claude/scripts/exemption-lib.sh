#!/bin/bash
# 豁免共享逻辑
# 供 closeout / pre-commit / harness-commit 复用。

PROJECT_ROOT_EXEMPTION_LIB="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

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

frontmatter_list_values() {
  local file="$1"
  local key="$2"
  local raw

  raw="$(frontmatter_value "$file" "$key")"
  raw="${raw#[}"
  raw="${raw%]}"

  [[ -z "${raw//[[:space:]]/}" ]] && return 0

  IFS=',' read -ra items <<< "$raw"
  for item in "${items[@]}"; do
    echo "$item" | sed 's/^ *//;s/ *$//'
  done
}

frontmatter_set_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    NR == 1 && $0 == "---" { in_fm = 1; print; next }
    in_fm && $0 == "---" {
      if (!replaced) print key ": " value
      in_fm = 0
      print
      next
    }
    in_fm && $0 ~ ("^" key ":") {
      print key ": " value
      replaced = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

trace_missing_ids() {
  local root="${1:-$PROJECT_ROOT_EXEMPTION_LIB}"
  bash "$root/.claude/scripts/trace.sh" 2>/dev/null | awk '/^  ❌ /{print $2}'
}

trace_missing_ids_subset_of_covers() {
  local file="$1"
  shift
  local ids=("$@")
  local covers=()
  local cover id found

  while IFS= read -r cover; do
    [[ -n "$cover" ]] && covers+=("$cover")
  done < <(frontmatter_list_values "$file" "covers")

  for id in "${ids[@]}"; do
    found=1
    for cover in "${covers[@]}"; do
      if [[ "$cover" == "$id" ]]; then
        found=0
        break
      fi
    done
    (( found == 0 )) || return 1
  done

  return 0
}

exemption_is_active() {
  local file="$1"
  local status scope expires today

  status="$(frontmatter_value "$file" "status")"
  scope="$(frontmatter_value "$file" "scope")"
  expires="$(frontmatter_value "$file" "expires")"
  today="$(date +%F)"

  [[ "$status" == "approved" ]] || return 1
  [[ "$scope" == "trace" ]] || return 1
  [[ -n "$expires" ]] || return 1
  [[ "$expires" > "$today" || "$expires" == "$today" ]] || return 1
}

trace_exemption_is_applicable() {
  local file="$1"
  shift
  local ids=("$@")
  local mode

  exemption_is_active "$file" || return 1
  ((${#ids[@]} > 0)) || return 1

  mode="$(frontmatter_value "$file" "mode")"
  case "$mode" in
    one_shot)
      return 0
      ;;
    until_resolved)
      trace_missing_ids_subset_of_covers "$file" "${ids[@]}"
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

find_applicable_trace_exemption() {
  local explicit="${1:-}"
  shift || true
  local ids=("$@")
  local file

  if [[ -n "$explicit" ]]; then
    [[ -f "$explicit" ]] || return 1
    trace_exemption_is_applicable "$explicit" "${ids[@]}" || return 1
    echo "$explicit"
    return 0
  fi

  for file in "$PROJECT_ROOT_EXEMPTION_LIB"/docs/exemptions/*.md; do
    [[ -f "$file" ]] || continue
    if trace_exemption_is_applicable "$file" "${ids[@]}"; then
      echo "$file"
      return 0
    fi
  done

  return 1
}

mark_exemption_consumed() {
  local file="$1"
  local commit_sha="$2"
  local today="${3:-$(date +%F)}"

  frontmatter_set_value "$file" "status" "consumed"
  frontmatter_set_value "$file" "consumed_by_commit" "$commit_sha"
  frontmatter_set_value "$file" "consumed_date" "$today"
  frontmatter_set_value "$file" "last_used_commit" "$commit_sha"
  frontmatter_set_value "$file" "last_used_date" "$today"
}

record_exemption_usage() {
  local file="$1"
  local commit_sha="$2"
  local today="${3:-$(date +%F)}"

  frontmatter_set_value "$file" "last_used_commit" "$commit_sha"
  frontmatter_set_value "$file" "last_used_date" "$today"
}
