# 豁免协议

豁免不是口头许可，而是受控工件和状态机。

## 什么时候允许豁免

仅在以下情况允许申请豁免：
- 本次变更是局部修复，但仓库存在与本次范围无关的历史门禁债
- 当前阻塞来自已知系统缺口，且已明确后续修复路径
- 不豁免会导致安全或线上故障修复被不相关历史债阻断

## 什么时候不允许豁免

- 为了跳过本次变更自己引入的问题
- 为了绕过本应在当前任务中补齐的文档交接
- 没有人类明确审批

## 豁免文档位置

使用 `docs/exemptions/*.md`。

豁免文档最少包含：
- frontmatter：`status`、`scope`、`mode`、`reason`、`approved_by`、`approved_date`、`expires`
- `until_resolved` 模式必须声明 `covers`
- 系统回写字段：`consumed_by_commit`、`consumed_date`、`last_used_commit`、`last_used_date`
- `## 背景`
- `## 允许跳过`
- `## 约束`
- `## 退出条件`

## 当前支持的 scope

- `trace`：允许 `closeout` 与 pre-commit 在 trace 未闭合时以豁免模式继续

## 生命周期

- `draft`：草稿，系统不可使用
- `review`：待审批，系统不可使用
- `approved`：可被系统加载
- `consumed`：一次性豁免已被成功提交消耗，系统不可再次加载
- `expired`：已过期，系统不可再次加载
- `revoked`：被人工撤销，系统不可再次加载

## 模式

- `one_shot`：只允许放行一次提交；提交成功后由 `harness-commit.sh` 自动回写为 `consumed`
- `until_resolved`：允许在声明的 `covers` 范围内重复使用；每次成功提交后记录 `last_used_commit`

## 原则

- 豁免必须有过期时间
- 豁免只针对明确 scope，不做全局免检
- 豁免存在时，系统仍应输出原始失败信息，只是把它降级为受控例外
- 只有 `status=approved` 的豁免才会被 `closeout` / `pre-commit` 加载
- `one_shot` 的状态推进必须由脚本自动完成，不依赖 Agent 记忆
