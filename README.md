# DouyinDisc · TrollFools

目标仅为 `com.ss.iphone.ugc.Aweme`，最低 iOS `15.0`，首测设备 iOS 16.5。作者 Xiaofei，插件标识 `com.minis.douyindisc`。

## 功能和范围

- 用用户提供 `10001.zip/10001.png` 原图（512×512 RGBA）替换短视频右侧分享按钮下方圆盘封面，图片编入单个 arm64 `.dylib`。
- 允许版本字面 `39.90` 或 `39.9.0`，另严格要求 build `399017`；用户提供的同版IPA已实际确认为39.9.0/399017。其他build不注入展示逻辑，兼容性不外推。
- 根据同版 ObjC 元数据，只在 `AWEMusicCoverButton` 的公开 `layoutSubviews` / `didMoveToWindow` 回调后处理，完整ABI验签、原实现恰一次转发。首次仍要求右rail几何及局部唯一分享/转发配对；相邻一屏incoming item在进入可见区域之前准备。不是用文字或坐标匹配任意控件。
- 按精确owner/ivar/type读取已有原生封面、黑底、guidanceLabel/guidanceView等视觉对象，视觉alpha租约隐藏，不改原图/文字/布局/事件/原生动画，不再反复压制layer.contents。包含“拍同款”文字后面独立背景。
- “听抖音”根据精确 `AWEPlayInteractionListenFeedView` 祖先及其 `_musicButton == 当前button` 校验，处理它的耳机图标、标题、渐变背景兄弟视图，不隐藏宿主或点击按钮。
- 每个item拥有独立的新图layer，直接挂在按钮下而非原生旋转封面下；共享同一个单调时间epoch，每圈7秒，切视频/同对象复用/模式切换不从零开始，视频暂停也继续转。系统减少动态效果打开时停自转。
- 布局/入窗时换图；只对至多64个弱引用已知控件做0.1秒common-mode轻量复核，滚动时不再全树扫描。启动/恢复前台仅做一次有界bootstrap。失活只停表保留视觉层，临时key变化和分享不主动还原，不保活不唤醒。
- 不添加面板、网络、业务日志、账号或内容采集，不改分享箭头、数量和其他控件。

## 证据与未验证项

用户在0.10/0.30截图确认普通盘换图及文字消失，但0.30残留黑半盘、听抖音未换、滚动闪原图/旋转重启仍为真机失败。0.40的同版静态证据见 [docs/douyin399-evidence.md](docs/douyin399-evidence.md)；静态分析不是运行时命中证明。真实UIKit宿主模拟完整同类型字段/继承关系，覆盖黑底像素、异步原图更新、多个item相位、耳机兄弟层、原点击/实际UIActivityViewController、真实窗口夺key和脱离恢复。宿主和实际抖音必须分开验收，尤其未真实运行iOS16.5控制中心/App切换器快照。

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
