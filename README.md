# DouyinDisc · TrollFools

## 3.70.1：修复照片选择器下滑卡死

3.70 把系统 presentation controller 的 delegate 换成了自带代理，PHPicker 是远程视图服务，delegate 被顶掉后收不到自己的退场回调，模态交接停在半途：设置页的 `presentedViewController` 一直悬着，行内按钮和开关随之全部无响应。3.70.1 删除该代理，不再改写任何系统 delegate，也不再从定时器里强制 dismiss。

改为被动观察：0.2 秒轮询只在 picker 不处于 presenting/dismissing 时读取 `presentingViewController` 与窗口归属，一旦 picker 已脱离宿主就回收会话并撤销空票据；只有连续 1 秒确认有 presentation 却完全没有窗口时才做一次无动画清理，清理后仍不恢复则直接放行状态。选择入口增加门禁 `douyindisc_canPresentPicker`，只有真正可见的模态才阻挡新一次选择，僵尸模态会被释放并允许重试。用户点击“完成”后走同一条路径，若此刻正在被手指下滑则不再二次 dismiss。

UIKit 回归继续模拟“没有 adaptive 回调”的 picker 退场，检查两个素材按钮和开关可再次点击、票据撤销、配置不变；源码契约新增断言，禁止 `presentation.delegate=`、`presentationControllerWillDismiss:`、`presentationControllerDidDismiss` 和整块 `DouyinDiscPickerDismissProxy` 回到工程。真机上手势轨迹与遮挡层销毁仍需你实测。

UIKit回归模拟没有adaptive回调的picker退出并检查两个素材按钮和开关可再次点击；它不模拟真实手指轨迹，也不能证明PhotosUI移除的遮挡层全部销毁。照片下滑暗屏仍必须由用户真机验收，不能把CI通过等同于真机通过。

素材行采用独立的照片按钮和文件夹按钮，分别直接打开系统照片选择器与文件选择器，不再叠加来源菜单。设置页重新出现时，如果当前picker已不在展示/退场状态且取消代理未触发，则按picker对象身份回收此会话并撤销空选择票据；取得有效provider的导入票据会保留。无固定延时清理。

模拟器回归依次覆盖：未选择下滑关闭且不发delegate、重新进入照片并空结果取消、直接打开文件选择器并取消；检查取消后的亮度、照片/文件/开关命中、票据撤销以及图片和配置保持不变。此仍不是用户设备真机验收。

在每项卡片上直接标明两个滑块的用途：第一条“透明度”控制替换图标透明度（0%–100%）；第二条“图标大小”控制图标相对原标签的尺寸（默认 100%，范围 50%–150%）。保留原图片按钮、删除按钮及其间距。

本次未在用户抖音进程取得残留遮罩的运行时对象，修复针对已证实的模态交接与取消状态管理缺口；实际取消效果仍需真机验收。

修复导航图标定位与原文字残留，提供每项 50%–150% 独立大小调节；入口插入根设置“通用”分组，紧跟运行时识别到的“抖音图层”项，黑字 `DouyinDisc`。找不到原生锚点时跳过，不猜固定位置。素材按钮仅在对应开关成功开启后可用；关闭开关会撤销在途导入，保留原图。选中状态显示照片图标、“更换图标”和独立缩略图，删除按钮贴近素材按钮。

每项独立控制：首页顶部 9 个分类、底部 4 个导航文字。图标以顶部 tab 中心 / 底部标签矩形为定位基准，不更改中间“+”、顺序、原点击或角标。

顶部：推荐、关注、同城、精选、商城、团购、直播、热点、经验。底部：首页、朋友、消息、我。

目标 App `com.ss.iphone.ugc.Aweme`，仅适配版本 `39.9.0` / build `399017`；最低 iOS 15.0。作者 Xiaofei，插件标识 `com.minis.douyindisc`。TrollFools 单文件 arm64 `.dylib`。

## 图标配置

设置卡片的第一条滑块标为“透明度”（0%–100%），控制替换图标透明度；第二条标为“图标大小”（默认 100%，范围 50%–150%），控制图标相对原标签尺寸。每项都有独立替换开关与图片来源。可从系统照片或文件选择图片；图片缩小到最长边 512 px 后存入抖音沙盒 `Documents/DouyinDisc/Navigation/`，配置文件为 `settings.plist`。关闭开关或清除自定义图片后恢复原文字。图片使用原比例，不拉伸；图片本身的透明度和滑条不透明度相乘。

## 原圆盘功能

保留圆盘替换、StyleOne 与 SingleSong 半盘修复、“拍同款/玩同款”精确隐藏、原生点击/分享，以及中心环 90%、外圈 50% 的同步旋转。1.50 移除的“圆盘取证”按钮、日志采集和导出不再包含。

## 边界与验收

静态定位依据是用户提供的抖音 build 399017 同版样本；真实设备上的主设置入口命中、导航视图树匹配、13 项显示、原生角标/点击以及照片/文件导入仍需真机验收。不能把模拟器回归或 Actions 成功当作设备已验证。其它抖音 build、横屏和 iPad 不承诺适配。

安装时先在 TrollFools 移除旧版，再注入本版并完全退出、重开抖音。进入“我→菜单→设置”，在“通用”分组找到“抖音图层”下方的 DouyinDisc，先开启单项再导入图片测试。故障反馈提供抖音版本、被替换项目的截图；闪退附对应 `.ips`。

## 构建与测试

```sh
export DEVELOPER_DIR="$(python3 scripts/toolchain.py select-xcode)"
python3 scripts/toolchain.py prepare
python3 tests/run_tests.py -v
python3 scripts/run_uikit_tests.py
./build.sh
python3 tests/verify_dylib.py --project . artifacts/DouyinDisc.dylib
```
