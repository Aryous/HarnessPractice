# requirements.trace.yaml Schema

## 角色

`requirements.trace.yaml` 是溯源体系的**源头注册表**。
它注册所有 R 和 F 条目，并声明哪些条目应被 trace.sh 追踪。

下游文档（tech-decisions、design-spec、exec-plan 等）的 sidecar 是**消费端**，声明对源头条目的覆盖关系。本文件只定义源头 schema。

## 完整 Schema

```yaml
# docs/product-specs/requirements.trace.yaml
document: docs/product-specs/requirements.md
role: source
generated_by: req-review

requirements:
  - id: R1.1                    # 格式：R + 章节编号
    name: 简历内容编辑            # 需求名称，与文档标题一致
    priority: P0                # P0 / P1 / P2

findings:
  - id: F06                     # 格式：F + 两位数字编号
    name: 技能等级控件            # 发现名称
    severity: S0 | S1 | S2      # 严重性评级
    journey: 编辑               # 所属用户旅程
    related: [R1.1]             # 关联需求 ID 列表
    disposition: open            # 处置状态（见下）
    # 以下字段仅 discarded / deferred 时必填
    reason: ""                  # 处置原因
    decided_by: ""              # 决策人
    decided_date: YYYY-MM-DD    # 决策日期

trackable:                      # trace.sh 直接读取的追踪清单
  - R1.1
  - F06
```

## 字段说明

### requirements[]

| 字段 | 必填 | 说明 |
|---|---|---|
| id | 是 | `R` + 章节编号（如 R1.1、R3.3） |
| name | 是 | 与文档中 `### X.Y` 标题一致 |
| priority | 是 | P0 / P1 / P2 |

### findings[]

| 字段 | 必填 | 说明 |
|---|---|---|
| id | 是 | `F` + 两位数字（如 F01、F23） |
| name | 是 | 发现名称 |
| severity | 是 | S0（阻断核心链路）/ S1（功能缺陷）/ S2（体验问题） |
| journey | 是 | 所属用户旅程 |
| related | 是 | 关联需求 ID 列表 |
| disposition | 是 | 处置状态 |
| reason | 条件 | discarded 或 deferred 时必填 |
| decided_by | 条件 | discarded 或 deferred 时必填 |
| decided_date | 条件 | discarded 或 deferred 时必填 |

### disposition 值

| 值 | 含义 | 进入 trackable |
|---|---|---|
| open | 已识别，待处理 | 是（S0/S1） |
| resolved | 已有代码实现 | 是 |
| discarded | 有意不做 | 否 |
| deferred | 推迟到未来版本 | 否 |

### trackable[]

显式列出 trace.sh 应追踪的 ID。推导规则：

- 所有 R 条目
- disposition 为 `open` 或 `resolved` 且 severity 为 S0 或 S1 的 F 条目
- `discarded`、`deferred`、S2 条目不进入

## 不包含的内容

- **Q（裁决）**：Q 是决策记录，不进入溯源体系。Q 与 F 的关联仅在文档正文中以 `[FXX]` 形式引用
- **下游覆盖关系**：由各下游文档的 sidecar 声明，不在源头注册表中
- **代码标注覆盖率**：由 trace.sh 在 src/tests 中 grep `@req` 标签获取，不在此文件中
