# Zoo Breakout — Claude 开发管理手册

Godot 4.7 · GDScript 静态类型 · 3D 灰盒 45° 正交。设计/架构/阶段以 `docs/` 为准，本文件只写**怎么干活**。

## 必读

- 设计支柱与锁定决策：`docs/DESIGN.md`
- 分层铁律与 Architect 门禁：`docs/ARCHITECTURE.md`（Content → GamePlay → Core，只能向下依赖）
- 当期范围：`docs/P2_CHECKLIST.md`（「本切片不做」= 默认拒绝）
- 待修清单：`docs/qa_reports/latest_report.md`
- 角色分工沿用 `.cursorrules`（QA / Dev / Architect / PM / Designer）

## 质量门禁（每次改动后必跑）

```bash
tools/run_tests.sh            # 全部套件
tools/run_tests.sh p0_regression p2_run_reset   # 指定套件
```

- 失败判定：退出码非 0，或输出含 `FAIL` / `FINDING` / `SCRIPT ERROR` / `ERROR:`。
- 红了不交付。修 bug 先补能复现的断言（放 `prototypes/pN_*.gd`，`quit(0 if 无失败 else 1)`）。
- 视觉/手感改动：用非 headless 截图自查（`--path . -s <script>` 抓 viewport），headless 看不到画面。

## 改动纪律

- 先定落层再写码；GamePlay 不按物种 id 分支，只认 `CapabilityIds` / Resource。
- 触及 `FollowCamera` 数学、`.gdshader`、新 Autoload/全局状态机、`Clock.Phase` 语义 → 先出方案给用户确认。
- 跨场景状态（Alert / OfficeStorage / Clock）新开局统一走 `RunLifecycle.reset()`。
- 分层由 `p2_hygiene` 静态扫描把关：Core 不碰玩法/内容符号，GamePlay 不碰具体关卡/UI/交互物脚本。
- 昼夜/天数：`Clock.day` 在黎明自增（`Clock.advance()` 是唯一推进入口，勿复制状态机）；每日结算在 `RunSession`。
- `Clock` 只在场景树里有 `zoo_world` 时走时（标题/结算不吃白天时长）。
- 文案中文；数值进 `content/game_const.gd`，不散落魔法数。
- 里程碑结项：勾 checklist + `docs/TECH.md` 状态一句 + QA 报告条目 `[x]`。

- 新增 `class_name` 脚本后先跑 `godot --headless --path . --import` 刷新类缓存，否则其他脚本报找不到类型。
- 关卡数据（搜集点等）写在 `content/levels/*_gather.gd` 这类数据文件，几何脚本只负责实例化。

- 世界空间文字一律用 `ProximityLabel`（`set_info(全文)`，首行即远距离短名），不要再手写 `Label3D` 字号/billboard。
- 测试里要走完整夜间施工用 `RouteHelper.finish(tree, interactable, actor)`；需要加速读条设 `Game.work_time_scale`。

## Git

- 远程：`origin` = `https://github.com/CoraStarX/ZooBreakout.git`，主分支 `main`。
- 提交署名（仓库本地配置）：`corax <CoraStarX@users.noreply.github.com>`；提交信息末尾带 Claude 的 Co-Authored-By。
- 只在用户要求时提交；**推送前必须得到用户明确同意**（推送即发布）。提交前先跑 `tools/run_tests.sh`，红了不提交。
- `.agents/`、`skills-lock.json` 是 Cursor 遗留工具，已 gitignore。

## 二进制路径

`/Applications/Godot.app/Contents/MacOS/Godot`（可用 `GODOT=` 覆盖）。
