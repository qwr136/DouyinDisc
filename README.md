# DouyinDisc · TrollFools

## 1.50：移除临时圆盘取证

本版从生产 dylib 中删除视图采集器、浮动按钮、JSONL 写入、定时采样及日志分享导出，不再生成圆盘视图日志。保留 1.40 已验证的 SingleSong 独立半盘与 StyleOne 修复、精确隐藏“拍同款/玩同款”、原生点击，以及中心环 90% / 外圈 50% 的同步旋转。

目标 App：`com.ss.iphone.ugc.Aweme`，仅接受 build `399017`；最低 iOS `15.0`，设备基线 iOS `16.5`。作者 Xiaofei，标识 `com.minis.douyindisc`。产物为 TrollFools 单文件 arm64 `.dylib`，不含越狱注入库。

安装：在 TrollFools 移除 1.40，注入本版 dylib，然后完全退出并重开抖音。此版没有设置面板，也不包含首页顶部分类栏或底部导航栏文字替换；这些是后续独立功能。

## 保留行为

- 内嵌原始图与清晰版 PNG；清晰版仅提高半透明笔画 alpha，不改变白色 RGB、图案或尺寸。
- 替换图挂在已配对的局部画布上；外圈不透明度 50%、中心环 90%，共用单调时钟持续旋转，每圈 7 秒。视频暂停时仍旋转；开启“减少动态效果”时停止自转。
- 仅对已识别的原生音乐按钮与验证过的视觉子层使用可撤销遮罩/alpha 租约；不隐藏宿主或按钮，不改原生布局、点击和分享行为。
- “拍同款”和“玩同款”仅按精确标签、已匹配按钮及局部几何隐藏，不扩展到其他文本或控件。
- “听抖音”入口仅在宿主类和音乐按钮身份都精确匹配时隐藏已核实的耳机图标、标题与背景。
- 仅复核弱引用的已知控件；失活时停止刷新，回前台按统一相位续转。不保活、不唤醒、不访问网络。

## 设备依据与边界

历史真机记录显示 StyleOne 与 SingleSong 的黑色半盘分别位于音乐按钮遮罩以外的独立视觉层。脱敏证据保留在 [StyleOne 设备记录](docs/style-one-device-080.md)、[SingleSong fixture](tests/fixtures/device-single-song-120.json) 和视觉回归用例中，仅用于说明修复依据；当前生产代码不含取证器或日志导出功能。

本插件只针对抖音 `39.9.0` / build `399017` 已知布局。其他 build、横屏、iPad 或未知控件不保证替换。设备耗电、其他插件兼容性及所有页面场景未全部真机验证。源码测试与 Actions 构建不能替代 TrollFools 安装和目标设备验收。

## 构建与测试

在符合随附锁策略的原生 arm64 Mac 上运行：

```sh
export DEVELOPER_DIR="$(python3 scripts/toolchain.py select-xcode)"
python3 scripts/toolchain.py prepare
python3 tests/run_tests.py -v
python3 scripts/run_uikit_tests.py
./build.sh
python3 tests/verify_dylib.py --project . artifacts/DouyinDisc.dylib
```

`build.sh` 会先核验工具链，再使用锁定的 iPhoneOS SDK 编译、签名并验库。GitHub Actions 运行源码与 iOS 模拟器 UIKit 回归，上传 dylib 和构建证据，不自动创建 Release。
