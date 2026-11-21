# 本次0.80真机日志 → StyleOne独立半盘

## 输入与身份

用户上传 `DouyinDisc-visual-trace.jsonl`，85,821 bytes/134条JSONL；App39.9.0/build399017，iOS16.5(20F66)，实际dylibUUID `9733D74A-EF0C-398D-B5E9-565DD6C68E9C`与0.80交付库一致。正常user-stop，时长14.5686秒；不是旧0.70混入。原始日志/用户截图不提交公开仓库；`tests/fixtures/device-style-one-080.json`只保留技术类名、匿名ID、几何、透明度、背景与关系，无PID/session/账号/图像/正文。

## 本次实际层级

- view18：`AWEPlayInteractionStyleOneMusicView`，parent16，alpha0.4436。
- view26：`AWEMusicCoverButton`，parent18；layer25上已有插件的透明mask50。
- view22：`UIView`，parent18，非交互，窗口矩形[385,826.6667,32,32]；layer21 bounds44×44，cornerRadius22、clips=true。
- view24：`UIImageView`，parent22，非交互且alpha1；窗口矩形[385,848.2424,32,10.4242]。
- layer23（view24 backing）：parent21、bounds44×14.3333、position[22,36.8333]、background[0,0,0,0.6]、opacity1、无mask、无shadow、无contents。
- 刷新前后共27组均显示button mask仍owned；visuals只含34/36/32/30/20/26，不含24。view20“玩同款”已alpha0。
- 插件新图layer52自身opacity1且挂到canvas layer3，绕开了view16/18的alpha分支，因而比其他原生装饰明显更白。

黑色填充和圆形裁剪共同形成底部半盘；它与button是不同分支，不可能被button自身mask覆盖。这是本次最强对象归属证据。日志未直接导出私有ivar与ID24的指针同一性；同版metadata及构造链的字段/类型/父关系匹配，并在实现中再次以实际对象关系核验，而非硬编码匿名ID。

## 同版静态对应及实现边界

`AWEPlayInteractionStyleOneMusicView` fields：`_musicButton @"AWEMusicCoverButton"`、`_playInteractionCircleMaskView @"UIView"`、`_playInteractionMaskView @"UIImageView"`。getter均 `@16@0:8`；circle getter IMP0x12fa100c、plate getter0x12fa1074。这些地址只作399017证据，不用于运行时偏移。getter包含懒创建，本补丁不调用它们；通过class/ivar完整typeencoding后读取已有对象。

仅当宿主为control直接父view，宿主_musicButton与control同一对象，circle.superview==host，plate.superview==circle，plate为非交互UIImageView且不在button子树中，才将plate加入既有alpha+ownedmask租约。不要隐藏host、circle、button或所有UIImageView。授权/父链变化仍走原恢复，再严格初始分享配对；epoch与所有权规则不变。

新图整体opacity0.5，在无隐式动画事务中写入；清晰图RGB/alpha字节不再改，上方按钮透明度不写。现有诊断入口从生产启动断开，文件不删除。新增真实UIKit反例先复现“按钮mask在、独立黑半盘仍可见”，再绑定精确字段、验证真实栅格黑像素消失；另验证父链/交互拒绝、恢复、实际hitTest、phase、50%opacity。源码与Actions通过不代替用户安装新0.90后的同场景验收。
