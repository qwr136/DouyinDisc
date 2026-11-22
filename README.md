# DouyinDisc · TrollFools

## 1.60：导航文字自定义图标

在抖音主“设置”页增加 DouyinDisc 入口，可分别配置首页顶部 9 个分类标签和底部 4 个导航文字：独立启用替换、选择自定义图片、调整透明度。图标按原文字区域等比显示，不改中间“+”、导航顺序、原生按钮及角标。

顶部：推荐、关注、同城、精选、商城、团购、直播、热点、经验。底部：首页、朋友、消息、我。

目标 App `com.ss.iphone.ugc.Aweme`，仅适配版本 `39.9.0` / build `399017`；最低 iOS 15.0。作者 Xiaofei，插件标识 `com.minis.douyindisc`。TrollFools 单文件 arm64 `.dylib`。

## 图标配置

每一项都有独立替换开关、图片和透明度滑条。可从系统照片或文件选择图片；图片缩小到最长边 512 px 后存入抖音沙盒 `Documents/DouyinDisc/Navigation/`，配置文件为 `settings.plist`。关闭开关或清除自定义图片后恢复原文字。图片使用原比例，不拉伸；图片本身的透明度和滑条不透明度相乘。

## 原圆盘功能

保留圆盘替换、StyleOne 与 SingleSong 半盘修复、“拍同款/玩同款”精确隐藏、原生点击/分享，以及中心环 90%、外圈 50% 的同步旋转。1.50 移除的“圆盘取证”按钮、日志采集和导出不再包含。

## 边界与验收

静态定位依据是用户提供的抖音 build 399017 同版样本；真实设备上的主设置入口命中、导航视图树匹配、13 项显示、原生角标/点击以及照片/文件导入仍需真机验收。不能把模拟器回归或 Actions 成功当作设备已验证。其它抖音 build、横屏和 iPad 不承诺适配。

安装时先在 TrollFools 移除 1.50，再注入本版并完全退出、重开抖音。进入“我→菜单→设置→DouyinDisc 导航图标”，先开启单项并导入图片测试。故障反馈提供抖音版本、被替换项目的截图；闪退附对应 `.ips`。

## 构建与测试

```sh
export DEVELOPER_DIR="$(python3 scripts/toolchain.py select-xcode)"
python3 scripts/toolchain.py prepare
python3 tests/run_tests.py -v
python3 scripts/run_uikit_tests.py
./build.sh
python3 tests/verify_dylib.py --project . artifacts/DouyinDisc.dylib
```
