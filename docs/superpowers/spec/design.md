# SkillHub — 设计规格

> 中心化 AI Coding Agent 技能管理器（macOS 原生应用）

## 1. 产品定位

**纯技能管理中心**，区别于 CC Switch 的"全能管家"定位。专注于一件事：让用户按来源/子分组/技能三级粒度，为多个 agent 独立开关技能，操作即生效。

## 2. 技术栈

| 层 | 技术 |
|---|------|
| 语言 | Swift 5.9+ |
| UI | SwiftUI + AppKit 混编 |
| 数据存储 | GRDB (SQLite) + Yams (YAML 配置) |
| 文件监听 | FSEvents |
| Agent 检测 | NSWorkspace / ProcessInfo |
| 符号链接 | FileManager |
| 包管理 | Swift Package Manager |

## 3. 系统架构

```
┌──────────────────────────────────────────────────┐
│ SwiftUI 主窗口 │
│ ┌─────────────────┐ ┌────────────────────────┐ │
│ │ 侧边栏 │ │ 技能 × Agent 矩阵 │ │
│ │ 来源列表 │ │ │ │
│ │ Agent 列表 │ │ 行列 toggle 开关 │ │
│ └─────────────────┘ └────────────────────────┘ │
├──────────────────────────────────────────────────┤
│ AppKit Menu Bar Extra │
│ 快速开关组 / 查看状态 / 打开主窗口 │
└──────────────────────────────────────────────────┘
 │
 ┌─────────────┼─────────────┐
 ▼ ▼ ▼
 ┌──────────┐ ┌──────────┐ ┌────────────┐
 │ SkillService│ │ AgentService│ │ SyncService │
 │ 安装/分组 │ │ 检测/配置 │ │ 符号链接同步 │
 └──────────┘ └──────────┘ └────────────┘
 │ │ │
 ▼ ▼ ▼
 ┌──────────────────────────────────────────────┐
 │ ~/.skillhub/ │
 │ ├── skills/ (技能文件本体) │
 │ ├── sources.yaml (来源 & 分组定义) │
 │ └── state.db (GRDB SQLite 运行时状态) │
 └──────────────────────────────────────────────┘
```

## 4. 核心服务

### 4.1 SkillService — 技能生命周期

**安装流程（规则驱动，无 AI）：**

```
用户输入地址（URL 或本地路径）
 → 来源类型识别（git / npm / local dir，纯规则匹配）
 → 拉取内容（git clone / npm install / 复制）
 → 内容解析（扫描 SKILL.md，识别子分组元数据）
 → 预览确认弹窗（展示技能列表、建议分组，用户可调整）
 → 安装执行（复制到 ~/.skillhub/skills/<source>/<name>/，写入 sources.yaml）
```

**来源识别规则：**

| 类型 | 判断条件 |
|------|---------|
| Git 仓库 | URL 匹配 `https://`、`git@`、`ssh://` 或 `.git` 结尾 |
| npm 包 | `@scope/name` 或 `package-name` 格式 |
| 本地目录 | 文件系统中存在且为目录 |

**技能识别：** 目录含 `SKILL.md` / `skill.md` → 识别为有效技能。

### 4.2 AgentService — Agent 检测

**检测策略（配置目录优先）：**

| Agent | 配置目录 | 可执行文件检查 |
|-------|---------|---------------|
| Claude Code | `~/.claude/` | `which claude` |
| OpenCode | `~/.opencode/` | `which opencode` |
| Gemini CLI | `~/.gemini/` | `which gemini` |
| Codex | `~/.codex/` | `which codex` |
| Copilot CLI | `~/.config/github-copilot/` | `gh extension list` |

**跨平台检测机制（后续扩展）：**

```swift
protocol AgentAdapter {
 func detect() -> [AgentInstance]
 func readConfig(_ instance: AgentInstance) -> [String]
 func writeConfig(_ instance: AgentInstance, skills: [SkillRef])
 func supportsHotReload() -> Bool
}
```

### 4.3 SyncService — 技能开关同步

**核心操作：符号链接**

-**开启**：在 agent 技能目录创建指向中央存储的符号链接
-**关闭**：删除符号链接
- 对于不支持技能目录的 agent，直接改写其配置文件

**同步触发：**
- 用户操作 toggle → 立即写入 + 判定是否需要通知 agent
- FSEvents 确保 agent 文件监听器感知变更（支持热加载的 agent 实时生效）

## 5. 数据模型

### 5.1 三层分组结构

```
来源 (Source) → 子分组 (Group) → 技能 (Skill)
```

一个技能可属于多个子分组，子分组属于唯一来源。

### 5.2 `~/.skillhub/sources.yaml`

```yaml
sources:
 superpowers:
 label: "Superpowers"
 origin: "https://github.com/obra/superpowers.git"
 groups:
 gsd: [brainstorming, tdd, debugging, writing-plans]
 review: [requesting-code-review, receiving-code-review]
 baoyu:
 label: "宝鱼技能集"
 origin: "https://github.com/example/baoyu-skills.git"
 groups:
 frontend: [frontend-design, component-test]
```

### 5.3 `~/.skillhub/state.db` (GRDB/SQLite)

```sql
-- 技能
skills (id, name, source_id, install_path, version, installed_at, updated_at)

-- 来源
sources (id, name, label, origin, installed_at)

-- Agent 实例
agents (id, name, config_path, detected_at, hot_reload_supported)

-- 启用状态
agent_skill (agent_id, skill_id, enabled)
```

## 6. UI 布局

### 6.1 主窗口

```
┌─────────────────────────────────────────────────────────┐
│ SkillHub [⚙] [↻] │
├────────────┬────────────────────────────────────────────┤
│ │ │
│ 📦 来源 │ 技能 / Agent 矩阵 │
│ ──────── │ ┌─────────────────────────────────────┐ │
│ ● super- │ │ Claude OpenCode │ │
│ powers │ │ 📦 superpowers │ │
│ ● baoyu │ │ 📁 gsd │ │
│ ● 自定义 │ │ brainstorming ● ○ │ │
│ │ │ tdd ● ○ │ │
│ ＋ 添加 │ │ debugging ● ● │ │
│ │ │ 📁 review │ │
│ ──────── │ │ code-review ○ ○ │ │
│ 🤖 Agent │ │ 📄 writing-plans ● ○ │ │
│ ──────── │ │ 📦 baoyu │ │
│ ● Claude │ │ 📁 前端 │ │
│ ● OpenCode │ │ frontend ○ ● │ │
│ ○ Gemini │ │ component-test ○ ● │ │
│ ● Codex │ └─────────────────────────────────────┘ │
│ │ │
│ │ [安装技能...] URL 或路径 [安装] │
├────────────┴────────────────────────────────────────────┤
│ ● 2 agents 就绪 | ◉ OpenCode 需重启 | 23 skills 已安装 │
└─────────────────────────────────────────────────────────┘
```

-**左侧栏**：来源列表（可筛选右侧内容）+ Agent 列开关
-**右侧矩阵**：树形行（来源→组→技能）× Agent 列 = toggle 单元格
-**底部栏**：安装输入 + 全局状态

### 6.2 操作粒度

| 层级 | 操作 |
|------|------|
| 来源级 | "对某 agent 全部开启/关闭此来源的所有技能" |
| 组级 | "对某 agent 全部开启/关闭此组的所有技能" |
| 技能级 | 单个 toggle 开关 |

### 6.3 Menu Bar Extra

```
┌──────────────────┐
│ SkillHub ● 2 │ ← 菜单栏图标，数字=在线 agent 数
├──────────────────┤
│ 📦 superpowers │
│ 📁 gsd │
│ 📁 review │ ← 点击组名快速切换（对该 agent 全开/全关）
│ 📦 baoyu │
│ ──────────────── │
│ 打开主窗口... │
│ 设置... │
│ 退出 SkillHub │
└──────────────────┘
```

## 7. 状态指示

| 图标 | 含义 |
|------|------|
| ● 绿 | Agent 在线，配置已同步 |
| ○ 灰 | Skill 对该 agent 已关闭 |
| ◉ 黄 | Agent 在线但需重启才能生效（不支持热加载） |
| ○ 空心 | Agent 已检测但未运行 |

## 8. 与 CC Switch 的差异

| | CC Switch | SkillHub |
|---|---|---|
| 定位 | 全能管家（API/MCP/Skill/Prompt/会话） | 纯 skill 管理中心 |
| 分组 | 无 | 来源 → 子分组 → 技能 |
| 开关粒度 | 单个 skill | 来源级 / 组级 / 技能级 |
| 安装来源 | GitHub / ZIP | git / npm / local 自动识别 |
| 平台 | 跨平台 (Tauri) | macOS 原生 |
| 体验 | Web UI | SwiftUI 原生 + Menu Bar |
| 启动 | ~500ms (WebView) | 瞬间 |

## 9. 后续可扩展

-**跨平台支持**：Swift 已支持 Linux/Windows，UI 层可后续移植
-**skill 市场集成**：对接 LobeHub、Claude Plugins Registry 等市场
-**协同模式**：不同用户/机器间通过 git 同步技能配置
-**依赖管理**：skill 之间可能有依赖关系，安装 A 自动安装 B