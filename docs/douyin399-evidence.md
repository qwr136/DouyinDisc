# 39.9.0 / 399017：同版静态证据与0.40改动

## 输入身份（仅记录元信息，不提交IPA或第三方图片）

- Bundle: `com.ss.iphone.ugc.Aweme`，实际 version `39.9.0`，build `399017`。
- IPA SHA256 `7fbcbb73f64545c96dbe006959ace61441e44aff21cc307fa0a28dbb71777dd0`。
- AwemeCore：arm64/subtype0，cryptid0，UUID `77060912-0370-30b1-be46-3dc96a297f76`，SHA256 `8d1321a69c6c34965c851dfb549758d97ab4a52fab93c9e9bbee0b64a9955b33`。
- 主程序 Aweme：arm64/subtype0，cryptid0，UUID `de4b0402-0fc8-32e9-b9a3-0e3b6a00303d`。
- 下列地址为同模块 unslid VM 地址（本文件VM基址为0），不作为运行时硬编码偏移。

## 普通圆盘的分层

`AWEMusicCoverButton` 继承 `AWEButton`；后者 `_imageContentView` 类型 `@"UIImageView"`，getter `-imageContentView @16@0:8` 在 `0x12e85dac`。其余相关字段均来自同版 ObjC ivar metadata：

| owner | 字段 | 完整类型 |
|---|---|---|
| AWEMusicCoverButton | _imageBgView | @"UIView" |
| AWEMusicCoverButton | _ownerImageView | @"UIImageView" |
| AWEMusicCoverButton | _guidanceLabel | @"UILabel" |
| AWEMusicCoverButton | _guidanceView | @"UIView" |
| AWEMusicCoverButton | _topCoverNoteImgV | @"UIImageView" |

`-guidanceView @16@0:8`，IMP `0x14019874`：创建UIView、layer radius18/masksToBounds、背景颜色 `AWEColorTextReverse2`、设置alpha、禁用交互、插到button index0（`0x14019938–0x140199ac`）。`-guidanceLabel` 位于 `0x14019780`。这证明文字后存在独立圆角背景，0.30只对UILabel和封面contents处理会保留该原生背景。静态身份不等于截图中每一像素都已在设备归属闭环。

`imageBgView` getter `0x12e85dd0`；`ownerImageView` getter `0x12e8962c`。原生旋转入口 `addRotateAnimationWithOwnerImageView`、`addRotateAnimationWithOutOwnerImageView`、`addRotateAnimationToView:`、pause/resume/stop分别处理原生图像层。新图不再作为原生旋转图像层的子层，从而不叠加原生旋转。

## 听抖音右侧入口

真正的宿主是 `AWEPlayInteractionListenFeedView`，不是仅凭名称猜测的 `AWEListenFeedButton`。其 `-initWithViewController: @24@0:8@16`（`0x152dacdc`）把以下四个子view加入宿主：

- `_musicButton @"AWEMusicCoverButton"`：仍是原点击按钮；getter `0x152db7ec` 把它自己的 imageBgView/imageContentView 设hidden。
- `_listenIconView @"UIImageView"`：实际耳机图；`-updateLayoutWithModel:context: v32@0:8@16@24`（`0x152db1f4`）设置名为 `feed_music_cover_icon` 的图。
- `_listenTitleLabel @"UILabel"`：标题来自模块服务，不能把可见文案等同于accessibilityLabel。
- `_backgroundView @"AWEGradientView"`：getter `0x152db940`，圆角22/masks/禁用交互。

它们是兄弟视图。新实现只有在祖先类身份成立且祖先 `_musicButton == 当前button` 时才暂时隐藏这些精确字段，不隐藏宿主、按钮或触摸区域。静态 `-makeConstraints`（`0x152dadfc`）给按钮和背景同中心44×44。

## 修改与验收边界

仅给 `AWEMusicCoverButton` 增加/替换公开 `layoutSubviews` 和 `didMoveToWindow`，runtime核验完整void ABI，原实现恰一次forward，继承方法用class_addMethod，不覆盖全局UIView。只通过运行时Ivar+完整类型读现有对象，不调用会懒加载的私有getter，不采用文件硬偏移。

新图是按钮layer的独立视觉层；原生视觉对象的alpha租约抑制黑底/封面/标题，原图、布局、动作、native动画均保留。布局/入窗时准备当前与相邻一屏feed项，多个surface使用同一单调时间epoch、7秒一圈；只对弱持有的已知对象做common-mode轻量复核，失活停表保留快照，不保活。所有变更仍须过源码、Apple编译/签名、真实UIKit宿主和抖音真机分层验收。

已知alpha边界：宿主在插件已设alpha0时再次有意写入相同0无法通过轮询区分；不声称完全识别相同值的外部写入。其他build无此同版证据；运行入口要求build399017，不扩大兼容。
