# Selene 音乐灵动岛设计

> **已废止（superseded）。** 用户确认「灵动岛」指**系统**媒体通知与锁屏控件，不是应用内顶部胶囊。  
> 产品意图 UX：保留底部 `MusicMiniPlayer` + `MusicMediaSession` / `audio_service` 通知栏与锁屏卡片；不再挂载应用内 `MusicDynamicIsland`。  
> 下文保留为 PR #9 的历史设计记录，不再作为实现依据。

日期：2026-09-20  
仓库：https://github.com/g3237582/Selene-Source  
状态：~~已在 PR https://github.com/g3237582/Selene-Source/pull/9 实现~~ → 应用内顶部岛已移除；系统 MediaSession 路径保留

当前产品播放控件：

```
MusicPlayerService (唯一播放真相)
    ├── MusicMiniPlayer（底部，保留）
    ├── audio_service / MusicMediaSession 锁屏与通知栏（保留，播放时初始化）
    └── MusicPlayerScreen（全屏页）
```

不再挂载应用内顶部 `MusicDynamicIsland`。`MusicPlayerRouteTracker` 仅用于在全屏页隐藏该岛，已一并删除。

## 背景

应用内已有：

- 底部 `MusicMiniPlayer` 迷你播放条
- 锁屏 / 通知栏媒体卡片（`audio_service` + `MusicPlayerService`）
- 全屏 `MusicPlayerScreen`（歌词页布局另有进行中的调整）

用户希望**再增加顶部灵动岛**，与底部迷你条**同时保留**。

## 目标

在听歌时提供顶部可展开的胶囊控件：收起时用环绕进度表达播放位置，展开后可快速控制播放，且不替代迷你条与锁屏卡片。

非目标：

- 不替换底部迷你条
- 不改锁屏 / 通知媒体会话的职责
- 本次不发版（仅合入由用户另行指示；发布需用户明确说「发布」）

## 选定方案

**方案一：应用内顶部悬浮胶囊（可展开控件）**

备选未采用：

- 方案二：顶部仅状态岛、无控件 → 操作能力弱
- 方案三：展开成大面板 → 与迷你条 / 全屏页职责重叠

## 外观

### 收起

- 位置：主界面顶部居中（避开状态栏 / 刘海安全区）
- 形态：深色小胶囊
- 内容：左侧小封面（无则音符占位）；可选极短歌名，空间不够可只保留封面
- 进度：细进度环**围绕胶囊外沿**，随 `MusicPlayerService` / media_kit 播放进度更新

### 展开

- 胶囊横向加宽
- 露出：上一首、播放/暂停、下一首（队列边界时禁用或隐藏对应键，与现有队列逻辑一致）
- 进度：可保持环绕，或改为展开态底部细条（实现时选视觉更稳的一种，行为等价）
- 收起：点岛外空白，或约 4 秒无操作自动收回

## 行为

| 条件 | 行为 |
|---|---|
| 有当前曲目，且不在全屏播放页 | 显示灵动岛 |
| 进入 `MusicPlayerScreen` | 隐藏灵动岛 |
| 从全屏返回且仍有曲目 | 再次显示 |
| 停止并清空队列 | 岛消失（与迷你条一致） |
| 点封面 / 歌名区域 | 打开全屏播放页 |
| 点胶囊其他区域 | 展开 / 收起 |
| 展开态点控件 | 调用同一套 `MusicPlayerService`（及现有 audio_service 桥接） |
| 切歌 | 岛内封面 / 标题 / 进度跟随更新 |

叠放：根布局 Overlay / Stack，浮在主内容之上；不遮挡底部迷你条；不改主导航结构。

## 与现有模块关系

```
MusicPlayerService (唯一播放真相)
    ├── MusicMiniPlayer（底部，保留）
    ├── audio_service 锁屏/通知卡片（保留）
    ├── MusicPlayerScreen 全屏页（岛在此页隐藏）
    └── MusicDynamicIsland（新增，顶部）
```

## 实现要点（供后续计划，非本阶段编码）

- 新建 widget（建议 `lib/widgets/music_dynamic_island.dart`），在应用根或主 Shell 挂载
- 用 `AnimatedBuilder` / 播放位置流驱动环进度
- 展开用 `AnimationController` 做宽度/控件显隐
- 检测当前路由是否为 `MusicPlayerScreen` 以控制显隐
- 单测：显隐条件、进度比例、展开/收起状态；UI 可用 widget 测试覆盖结构

## 验收标准

1. 有曲目时顶部出现环进度胶囊；全屏播放页不出现
2. 点开可上一首 / 播放暂停 / 下一首，与迷你条、锁屏控件控制同一播放器
3. 底部迷你条与锁屏卡片仍可用
4. 清空播放后岛消失
5. 不自动发版；仅开 PR，等用户指示再合并 / 发布

## 已确认结论摘要

- 顶部岛 + 底部迷你条都要
- 收起：小胶囊 + 进度条环绕；点开再出控件
- 有音乐就显示，全屏播放页除外
- 采用方案一
