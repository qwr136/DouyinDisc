# DouyinDisc · TrollFools

## 0.80 一次局部取证（不是残留底盘修复完成版）

用户0.60截图确认新图亮白清晰，但灰黑半盘仍在；另一张图明确为“玩同款”。本版保留0.60图像/旋转/遮罩行为，仅把精确文案允许项补为“拍同款”和“玩同款”，并按用户授权增加**默认关闭**的局部取证入口。没有拿静态猜测继续扩大父层隐藏。

1. 移除0.60后注入0.80，完全重开抖音。屏幕左侧有小按钮“圆盘取证”。未点击时不采集、不建日志、不启动诊断timer。
2. 停在能看到残底或玩同款的视频，点“圆盘取证”，保持抖音前台；采集最多20秒，预算到限也会提前停。可以慢切到另一个有残底的视频，不需要点音乐按钮或进入详情。
3. 按钮变“导出取证”后点它，分享 `DouyinDisc-visual-trace.jsonl` 原文件；也可采集时点“停止并导出”。**发回该日志即可，不用重传IPA、视频或素材。**
4. 文件只在App沙盒 `Documents/DouyinDisc/DouyinDisc-visual-trace.jsonl`，至多256KiB、1024事件；开始新一次取证会覆盖本地旧文件，先导出需保留的旧记录。切后台立即停采，不保活、不唤醒。

只记录已识别圆盘附近至多3个可见控件的技术类名、会话匿名序号、model/presentation几何及alpha/opacity、mask/background/shadow状态和刷新前后是否仍持有视觉租约。图遍历限局部共同容器及圆盘附近区域：每控件最多96访问/24个view/64个layer；额外4级祖先只记自身不遍历外侧后代。默认OFF直接短路；没有全局setter Hook。

**不导出**账号、标题、视频ID/URL、任意文本或accessibility值、图片像素、截图、网络数据、文件路径或对象地址。文案仅归类为已知 `shoot-same/play-same/other-label` 枚举。日志含App version/build、OS、PID、实际模块UUID以对应本次装机库。诊断开着时有有限额外主线程遍历/I/O，性能未真机测；局部状态未必能单次唯一归属外部渲染层，不能先承诺黑底已解决。完成取证后可换回0.60移除浮动入口，旧版附件不覆盖。

目标仅为 `com.ss.iphone.ugc.Aweme`，最低 iOS `15.0`，首测设备 iOS 16.5。作者 Xiaofei，插件标识 `com.minis.douyindisc`。

## 功能和范围

- 从用户提供的 `10001.zip/10001.png`（512×512 RGBA）生成同尺寸清晰版：白色RGB和透明背景位置不变，仅 `alpha=min(255,2*alpha)` 提升半透明笔画；不虚构高分辨率或AI重画。清晰图与原图解码回退均编入单个arm64 `.dylib`，无需另放素材。
- 0.60改为把新图挂到已完成唯一分享配对的局部共同画布上，不再继承音乐按钮分支的alpha；像素对齐位置，保持原尺寸及连续旋转epoch。仅对已验证音乐按钮的原生像素设置临时全透明layer mask，不改按钮UIView的alpha/hidden/userInteraction或点击链。对原生视觉字段保持alpha租约并加mask，避免宿主后写alpha或presentation动画又露出文字/底盘；mask所有权不属于本插件时不写回旧mask。
- 补回0.30真机曾有效的精确UILabel兜底；0.80起仅允许“拍同款”/“玩同款”：只查已匹配音乐按钮和直接局部容器、限定几何及最多96节点，不处理其他UIControl、分享面板或视频字幕。
- 允许版本字面 `39.90` 或 `39.9.0`，另严格要求 build `399017`；用户提供的同版IPA已实际确认为39.9.0/399017。其他build不注入展示逻辑，兼容性不外推。
- 根据同版 ObjC 元数据，只在 `AWEMusicCoverButton` 的公开 `layoutSubviews` / `didMoveToWindow` 回调后处理，完整ABI验签、原实现恰一次转发。首次仍要求右rail几何及局部唯一分享/转发配对；相邻一屏incoming item在进入可见区域之前准备。不是用文字或坐标匹配任意控件。
- 按精确owner/ivar/type读取已有原生封面、黑底、guidanceLabel/guidanceView等视觉对象，视觉alpha租约隐藏，不改原图/文字/布局/事件/原生动画，不再反复压制layer.contents。包含“拍同款”文字后面独立背景。
- “听抖音”根据精确 `AWEPlayInteractionListenFeedView` 祖先及其 `_musicButton == 当前button` 校验，处理它的耳机图标、标题、渐变背景兄弟视图，不隐藏宿主或点击按钮。
- 每个item拥有独立的新图layer，挂到已配对局部共同画布而非原生按钮/封面下；共享同一个单调时间epoch，每圈7秒，切视频/同对象复用/模式切换不从零开始，视频暂停也继续转。系统减少动态效果打开时停自转。
- 布局/入窗时换图；只对至多64个弱引用已知控件做0.1秒common-mode轻量复核，滚动时不再全树扫描。启动/恢复前台仅做一次有界bootstrap。失活只停表保留视觉层，临时key变化和分享不主动还原，不保活不唤醒。
- 不添加面板、网络、业务日志、账号或内容采集，不改分享箭头、数量和其他控件。

## 证据与未验证项

用户在0.10/0.30截图确认普通盘换图及文字消失，但0.30残留黑半盘、听抖音未换、滚动闪原图/旋转重启为真机失败。0.50仍有“拍同款”及底盘且图片发灰，不能沿用64UIKit通过声称修好。普通宿主同版静态链确认guidanceLabel/guidanceView属于音乐按钮自身，初始化alpha0后实际谁又写入非零仍未知；本轮以隔离该按钮全部原生视觉和补回已验文字兜底处理，不假定它们来自未知父层。具体压暗写入者仍未定位，提升源图alpha不保证消除所有祖先级整体压暗。0.60须再次在真实抖音验收。0.40的同版静态证据见 [docs/douyin399-evidence.md](docs/douyin399-evidence.md)；静态分析不是运行时命中证明。真实UIKit宿主模拟完整同类型字段/继承关系，覆盖黑底像素、异步原图更新、多个item相位、耳机兄弟层、原点击/实际UIActivityViewController、真实窗口夺key和脱离恢复。宿主和实际抖音必须分开验收，尤其未真实运行iOS16.5控制中心/App切换器快照。

已知副作用：仅适配已核build；新对象仍须局部分享配对和字段类型全验证，缺失/歧义/横屏/iPad/陌生布局可能保守不换。动态alpha相同值的宿主写入无法仅通过租约完全辨别；不声称所有外部显隐状态均有完美所有权。新的自转明确不跟随视频暂停；后台停刷新，回前台按全局时钟续相位。其他插件若覆盖同一方法/改子视图或隐藏分享按钮，可能不兼容。设备CPU/耗电与所有业务场景未测。第三方IPA及图像资源不进公开仓库。

## 安装和回退

TrollFools 选抖音，移除冲突旧圆盘库后注入 `DouyinDisc.dylib`，完全重启抖音。无需另放图片，无开关。推荐页连续切 5 条视频确认圆盘换图/转动，再点圆盘和分享，确认原跳转不变；进入评论、离开页面及切后台再回来验证恢复。无效果提供真实版本截图和圆盘局部录屏；闪退提供对应 `.ips`，不需要账号或视频链接。回退在 TrollFools 删除此注入库并完全重启。

## 构建与测试

在符合随附锁策略的原生 arm64 Mac 上：

```sh
export DEVELOPER_DIR="$(python3 scripts/toolchain.py select-xcode)"
python3 scripts/toolchain.py prepare
python3 tests/run_tests.py -v
./build.sh
python3 tests/verify_dylib.py --project . artifacts/DouyinDisc.dylib
```

`prepare` 准备固定来源及 `iPhoneOS16.5.sdk`。`build.sh` 会清除上次同名产物，工具链通过实查后才编译；原生 ad-hoc 签名、本机签名检查和离线 dylib 契约校验均通过后才提交新产物。随附工作流只上传 artifact，不创建 GitHub Release。

`tests/source_checks.py` 提供纯静态接口 `check_project(project, meta) -> list[str]`，不执行项目命令。`tests/verify_dylib.py` 提供 `inspect_dylib(path, manifest=None) -> dict`，返回可 JSON 序列化的证据（含同一次读取计算的 `size`、`sha256`）；无效输入抛出 `ValueError` 或 `OSError`。给出 `--project` 时另外比对 `tweak.json` 中的名称、包名和部署版本；不使用 deb 版本字段。校验只针对此模板生成的单架构设备 dylib，依赖为显式 Apple 系统库/公开框架白名单。扩展需要其他公开框架时，同时审查 SDK install name、编译参数和白名单。CodeDirectory 页哈希不能证明来源或设备信任，源码回归也不代表 Mac 构建、TrollFools 注入或真机行为已验证。
