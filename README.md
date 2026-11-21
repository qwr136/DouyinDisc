# DouyinDisc · TrollFools

目标仅为 `com.ss.iphone.ugc.Aweme`，最低 iOS `15.0`，首测设备 iOS 16.5。作者 Xiaofei，插件标识 `com.minis.douyindisc`。

## 功能和范围

- 用用户提供 `10001.zip/10001.png` 原图（512×512 RGBA）替换短视频右侧分享按钮下方圆盘封面，图片编入单个 arm64 `.dylib`。
- 仅接收实际版本字符串 `39.90` 或 `39.9.0`，两者分别列为允许项，不声称用户已确认两者等同；其他版本保持原样。
- 不 Hook 私有方法。前台每 0.25 秒在有界右侧视图树内，通过唯一音乐/拍同款控件、分享按钮、局部共同祖先和空间关系交叉验证；实际图层必须是唯一居中、非交互的 UIImageView。不匹配则不替换。
- 保留原生按钮、点击、布局和动画。只暂时抑制该 image layer 的封面像素、添加自有图片 layer；离开目标或失活时恢复仍由本插件持有的像素。原生异步更新优先，不覆盖新内容。
- 优先跟随原生旋转；连续三次未发现旋转时仅给自有图片 layer 加每圈 7 秒旋转，检测到原生转动即去掉自有动画。系统减少动态效果打开时不补转。
- 不添加面板、网络、业务日志、账号或内容采集，不改分享箭头、数量和其他控件。

## 证据与未验证项

同版抖音 IPA/真实层级尚未取得；`AWEMusicCoverButton` 仅为另版开源线索，不能当 39.90 已验证。首版是通过公开 UIKit 接口观测实际 UI 并保守匹配的测试候选，不保证该版本的控件命名、标签或 UIImageView 渲染路径匹配。自建 UIKit 宿主只验证本实现，不证明抖音真机有效。

已知副作用：静止时最多 0.25 秒换图延迟；原图异步重写或滚动期间可能短暂露出原图；多 renderer、控件层级不符合条件、横屏/平板/非中文标签、其他插件隐藏分享按钮时保守不处理。旋转采样不是性能或暂停播放语义证明；无原生转动但仍活动时补转，不感知视频暂停。新增前台有界 UI 扫描，设备 CPU/耗电未测。原图透明部分保留原控件背景或边框。

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
