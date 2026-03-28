# 执行计划 Sidecar Schema

消费端 sidecar，schema 与 arch-output 定义的消费端 schema 一致。

参考：`.claude/skills/arch-output/references/trace-schema.md`

## Schema

```yaml
document: docs/exec-plans/active/<name>.md
role: consumer
trace_from: docs/product-specs/requirements.trace.yaml
generated_by: plan

entries:
  - input: R1.1            # trackable ID
    disposition: covered    # covered / excluded / partial
    output: Task 1, Task 3  # 对应的 task
    note: ""

  - input: R4.1
    disposition: excluded
    output: ""
    note: v1 不含
```

## 字段说明

| 字段 | 必须 | 说明 |
|---|---|---|
| `document` | 是 | exec-plan 文件路径 |
| `role` | 是 | 固定 `consumer` |
| `trace_from` | 是 | 固定指向 requirements.trace.yaml |
| `generated_by` | 是 | 固定 `plan` |
| `entries[].input` | 是 | requirements.trace.yaml 中的 trackable ID |
| `entries[].disposition` | 是 | `covered` / `excluded` / `partial` |
| `entries[].output` | 条件 | disposition 为 covered/partial 时必填，标注对应 task |
| `entries[].note` | 否 | excluded/partial 时说明原因 |
