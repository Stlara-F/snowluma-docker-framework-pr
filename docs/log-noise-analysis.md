# 容器日志无害噪音汇总

> 基于 `_snowluma-dev_logs(2).txt`（运行时长约 6 小时）进行分析。
> 所有条目均为**无功能影响**的日志噪音，按类别整理。

---

## 1. Fluxbox 配置项读取失败

**行数**: 约 100+ 行，启动阶段密集出现

**日志示例**:
```
Failed to read: session.ignoreBorder
Setting default value
Failed to read: session.forcePseudoTransparency
Setting default value
Failed to read: session.colorsPerChannel
...
```

**根因**: Fluxbox 窗口管理器初次运行，配置项不存在，自动 Fallback 到默认值。涉及 session 级和 screen0 级约 40+ 个配置项。

**影响**: 无。Fluxbox 正常初始化行为。

---

## 2. Supervisor 安全警告

**行数**: 2 行，启动阶段

**日志**:
```
CRIT Supervisor is running as root.  Privileges were not dropped because no user is specified in the config file.
CRIT Server 'unix_http_server' running without any HTTP authentication checking
```

**根因**: `supervisord.conf` 中未指定 `user=` 以降权运行子进程；Unix socket 无认证。

**影响**: 低。容器内 root 运行是容器化场景的常见做法；Unix socket 仅本地可访问。

---

## 3. x11vnc IPv6 绑定失败

**行数**: 2 行，启动阶段

**日志**:
```
listen6: bind: Address already in use
Not listening on IPv6 interface.
```

**根因**: IPv6 端口 5900 已被占用（可能是同容器前一个 x11vnc 实例未完全释放）。

**影响**: 低。IPv4 端口 5900 正常监听，VNC 功能完全可用。

---

## 4. x11vnc 信息输出

**行数**: 约 20 行，启动阶段

**日志示例**:
```
Wireframing: -wireframe mode is in effect for window moves.
Scroll Detection: -scrollcopyrect mode is in effect...
XKEYBOARD: number of keysyms per keycode 7 is greater than 4...
X FBPM extension not supported.
Xlib:  extension "DPMS" missing on display ":1".
```

**根因**: x11vnc 正常启动时的诊断/提示信息，包括 wireframe 模式、滚动检测、键盘映射、DPMS 电源管理不可用等。

**影响**: 无。均为 x11vnc 标准输出。

---

## 5. QQ Electron 预加载信息

**行数**: 每 QQ 实例 3 行，共 9 行

**日志**:
```
not mini app.
[preload] succeeded. /opt/QQ/resources/app/major.node
resourcesPath: /opt/QQ/resources
```

**根因**: QQ Electron 启动时加载 native 模块的正常输出。

**影响**: 无。

---

## 6. Node.js SQLite ExperimentalWarning

**行数**: 1 行

**日志**:
```
(node:79) ExperimentalWarning: SQLite is an experimental feature and might change at any time
```

**根因**: Node.js 22 中 SQLite 模块为实验特性。

**影响**: 极低。SnowLuma 正常使用 SQLite 存储关系数据。

---

## 7. DBus login1 Inhibit 调用失败

**行数**: 3 行（PID 76, 77, 78 各一次）

**日志**:
```
[76:0628/031031.916208:ERROR:dbus/object_proxy.cc:590] Failed to call method:
org.freedesktop.login1.Manager.Inhibit: object_path= /org/freedesktop/login1:
org.freedesktop.DBus.Error.Spawn.ChildExited: Launch helper exited with unknown return code 1
```

**根因**: 容器内没有 `systemd-logind` 服务。QQ Electron 试图调用 D-Bus 接口阻止系统休眠，调用失败。

**影响**: 低。容器环境无休眠/关机概念，不影响功能。

---

## 8. QQ Electron DroppedFrame / LongTask

**行数**: 大量出现，贯穿全程

**日志示例**:
```
[224][1590829618232]DroppedFrame(1): host_id=1, time=1590827664348, latest_seq=40, interval=16666
[4331][1590993476810]LongTask(10): duration=2086ms, container=
[4359][1590993270828]LongTask(8): duration=4092ms, container=
```

**根因**:
- 运行 3 个 QQ Electron 实例（主 + 2 个额外账号），渲染负载高
- Guild（频道）面板加载大量 JS chunk（日志中 40+ 个 `intercepted_url`）触发长任务
- 部分 LongTask 长达 4 秒，DroppedFrame 因丢帧引起

**影响**: 中。影响 VNC 远程桌面操作体验，但**不影响** bot 消息收发和 OneBot 功能。

---

## 9. QQ hotUpdate 周期性检测

**行数**: 每小时一轮，每轮约 10 行

**日志**:
```
[QQ hotUpdate] ----- startAutoUpdate curVersion: 3.2.28-48517 -----
[QQ hotUpdate] hotUpdateApi getReadyVersionConfig suc
[QQ hotUpdate] hotUpdateApi getUpdateStatus:  false
[QQ hotUpdate] hotUpdateApi checkHasMultipleQQ:  true
[QQ hotUpdate] hotUpdateApi start check  3.2.29-49738  IsOnErrorVersion
[QQ hotUpdate] hotUpdateApi checkIsOnErrorVersion result: false
```

**根因**: QQ 每小时自动检查更新，检测到新版本 `3.2.29-49738`，但因 `hasMultipleQQ` 等多实例策略自动取消更新。

**影响**: 低。QQ 标准行为。

---

## 10. Bugly 崩溃收集文件不存在

**行数**: 2 行

**日志**:
```
[NativeCrashHandler.cpp][getCrashDetailBeanFromRecord][52]!!!! in NativeCrashHandler
getCrashDetailBeanFromRecord, open file error!!!, dumpFilePath:/app/qq-acct3/.config/QQ/crash_files/rqd_record.eup
```

**根因**: Bugly 初始化后尝试读取历史崩溃记录文件，但文件不存在。

**影响**: 无。首次运行或无崩溃时的正常情况。

---

## 11. MsgPush.Unknown Event0x210

**行数**: 多行，间歇出现

**日志**:
```
DEBUG [MsgPush.Unknown] Event0x210 unknown subType=382
DEBUG [MsgPush.Unknown] Event0x210 unknown subType=381
DEBUG [MsgPush.Unknown] Event0x210 unknown subType=349
```

**根因**: SnowLuma 收到 QQ 消息推送中未识别的 0x210 事件子类型。可能是新版 QQ 新增的事件类型。

**影响**: 低。SnowLuma 日志级别为 DEBUG 时可见，不影响已有功能。

---

## 12. X11 Atom Cache 缺失

**行数**: 1 行

**日志**:
```
[78:0628/035846.388130:ERROR:ui/gfx/x/atom_cache.cc:232] Add _NET_WM_WINDOW_TYPE_TOOLBAR to kAtomsToCache
```

**根因**: QQ Electron 渲染进程试图缓存 `_NET_WM_WINDOW_TYPE_TOOLBAR` 这个 X11 Atom，但该 Atom 不在 Chromium 的预缓存列表中。

**影响**: 极低。Electron 内部 warning，无行为影响。

---

## 13. VNC 不支持的编码扩展

**行数**: 多行，VNC 客户端连接时

**日志**:
```
rfbProcessClientNormalMessage: ignoring unsupported encoding type tightPng
rfbProcessClientNormalMessage: ignoring unsupported encoding type Enc(0x00000015)
```

**根因**: VNC Viewer 请求了 x11vnc 服务端不支持的编码格式。

**影响**: 无。x11vnc 自动降级到支持的编码。

---

## 14. xdg-open 找不到浏览器

**行数**: 约 100+ 行，间歇性爆发

**日志**:
```
/usr/bin/xdg-open: 882: x-www-browser: not found
/usr/bin/xdg-open: 882: firefox: not found
... (全部 16 种浏览器)
xdg-open: no method available for opening 'https://ssl.ptlogin2.qq.com/jump?...'
```

**根因**: 容器内未安装任何浏览器。QQ Electron 在以下场景调用 `xdg-open` 打开外部链接：
- SSO token 刷新（`ssl.ptlogin2.qq.com`）
- QZone、腾讯文档、邮箱等面板入口

**影响**: 低。SnowLuma 代码审计确认**零处依赖**浏览器或 `xdg-open`，不影响 bot 功能。

> 若需消除此噪音，可在 Dockerfile 中添加：
> ```dockerfile
> RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open && chmod +x /usr/local/bin/xdg-open
> ```

---

## 噪音总览

| # | 类别 | 数量级 | 是否可消除 | 建议 |
|---|------|--------|-----------|------|
| 1 | Fluxbox 配置项 Fallback | ~100 行 | 否 | 正常行为 |
| 2 | Supervisor 安全警告 | 2 行 | 是 | `supervisord.conf` 加 `user=root` |
| 3 | x11vnc IPv6 绑定失败 | 2 行 | 否 | 低优先级 |
| 4 | x11vnc 信息输出 | ~20 行 | 否 | 正常行为 |
| 5 | QQ 预加载信息 | 9 行 | 否 | 正常行为 |
| 6 | SQLite ExperimentalWarning | 1 行 | 否 | Node.js 层面 |
| 7 | DBus login1 失败 | 3 行 | 是 | 安装 `dbus-x11` 或接受 |
| 8 | DroppedFrame/LongTask | 大量 | 否 | 资源优化 |
| 9 | QQ hotUpdate | 每小时间歇 | 否 | 正常行为 |
| 10 | Bugly 文件不存在 | 2 行 | 否 | 正常行为 |
| 11 | MsgPush.Unknown | 间歇 | 否 | SnowLuma 行为 |
| 12 | X11 Atom Cache | 1 行 | 否 | Chromium 内部 |
| 13 | VNC 不支持的编码 | 间歇 | 否 | x11vnc 正常行为 |
| 14 | xdg-open 找不到浏览器 | ~100+ 行 | **是** | 加无操作 xdg-open 脚本 |
