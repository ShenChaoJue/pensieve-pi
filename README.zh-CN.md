# pensieve-pi

[English](README.md) | [简体中文](README.zh-CN.md)

一个包含 Pensieve 项目知识库技能的 pi 包。移植自 [kingkongshot/Pensieve](https://github.com/kingkongshot/Pensieve) v1.3.0，采用 MIT 许可证。

## 包结构

```text
pensieve-pi/
├── package.json
├── README.md
├── skills/
│   └── pensieve/
│       ├── SKILL.md
│       └── .src/
└── extensions/       # pi 生命周期集成
```

## 安装

从本地检出安装：

```bash
pi install ./pensieve-pi
```

仓库发布后安装：

```bash
pi install git:https://github.com/<owner>/<repository>.git
```

## 项目数据

Pensieve 将用户拥有的数据保存在各项目的 `.pensieve/` 目录下：

- `maxims/` — 持久化的 maxim（工程准则）和标准。
- `decisions/` — 架构决策及其权衡。
- `pipelines/` — 用于重复性任务的可复用流水线。
- `knowledge/` — 缓存的项目结构、边界和探索结果。
- `short-term/` — 新结论在提升或删除前的短期暂存区。

## 全局数据

Pensieve 还支持位于 `~/.pensieve/` 的共享数据根目录。可通过设置 `PENSIEVE_GLOBAL_ROOT` 使用其他位置。

```text
~/.pensieve/
├── maxims/              # 跨项目共享的工程准则（上限 20 条）
├── knowledge/           # 共享事实（上限 30 条）
├── pipelines/           # 共享流水线（上限 20 条）
├── short-term/          # 三个长期层的暂存镜像
│   ├── maxims/
│   ├── knowledge/
│   └── pipelines/
└── .state/              # 运行时产物
```

**显式启用。** 全局根目录不会自动创建：`pi install` 不会创建该目录，也不会在 `$HOME` 下写入任何内容。
安装后，使用以下幂等命令手动初始化一次；`PENSIEVE_SKILL_ROOT` 指向已安装的 `pensieve` skill 目录：

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/init-project-data.sh" --global
```

可选运行以下命令，启用 `~/.pi/agent/AGENTS.md` 注入通道：

```bash
bash "${PENSIEVE_SKILL_ROOT}/.src/scripts/sync-instructions.sh" --global
```

如果全局根目录不存在或被删除，Pensieve 会静默降级为纯项目级行为，不会报错。

项目根目录存储差异，全局根目录存储共性。全局数据没有 `decisions/` 层，因为架构权衡仍然与作出该决策的项目绑定。

写入条目前，Pensieve 会提出两个作用域问题：S1 询问条目是否引用了与仓库绑定的上下文；如果没有，S2 询问它在另一个项目中是否仍然成立。仅来自一个项目的证据保留在项目作用域，并可能获得 `scope-candidate` 标签。在两个或更多项目中重复出现的内容可通过 `refine` 提升。项目条目使用 `[[global:maxims/example]]` 形式的链接指向共享条目，每个条目都可在其 frontmatter 中声明 `scope: project | global`。

对于包含 `.pensieve/` 的项目，会话启动时会将全局 maxim 标题以及全局流水线/知识索引添加到 `additionalContext` 开头；完整条目正文仍可按需获取。不包含 `.pensieve/` 的项目不受影响。

## 工具

- **init** — 初始化项目数据并写入默认内容；`init --global` 以幂等方式初始化全局根目录，其中包含四条 maxim 和三条流水线。
- **upgrade** — 说明如何更新已安装的 pi 包。
- **migrate** — 迁移旧版数据并使当前目录结构保持一致。
- **doctor** — 检查项目和全局数据、链接、生成的状态、指令路由以及 frontmatter 的 `scope`；缺少全局目录或超过 20/30/20 上限会标记为 `MUST_FIX`，`scope-candidate` 条目会标记为 `INFO`，生成的图中还包含 Global 子图。
- **self-improve** — 从已完成的工作中记录可复用的结论。
- **refine** — 执行六项问题审查，其中包括 Q5 跨项目重复性检查；随后跨根目录提升符合条件的条目，并删除重复项，或将其缩减为带有项目特定差异的 `[[global:...]]` 指针。
- **sync-instructions** — 将项目流水线路由添加到 `AGENTS.md`；`sync-instructions --global` 会在 `<!-- pensieve:global-instructions:start -->` / `<!-- pensieve:global-instructions:end -->` 标记之间，将全局 maxim 和流水线索引写入 `~/.pi/agent/AGENTS.md`，使它们可用于所有 pi 会话。

原始 Claude Code 发行版使用 `.src/scripts/install-hooks.sh`；pi 用户无需运行它，因为 pi 扩展提供了生命周期集成。如果还安装了 Claude Code，维护操作可以同步其 `MEMORY.md`；设置 `PENSIEVE_DISABLE_AUTO_MEMORY=1` 可禁用该兼容行为。
