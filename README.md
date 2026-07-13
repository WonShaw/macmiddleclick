# MacMiddleClick

一个只使用 macOS 公开 API 的菜单栏小工具：按住 `Fn` 点击左键，将输入转换为标准鼠标中键（Button 2）。

支持：

- MacBook 内置触摸板按下
- 触摸板“轻点来点按”
- Magic Trackpad
- 普通鼠标左键
- 按住拖动时转换为中键拖动

## 构建与运行

1. 使用 Xcode 打开 `MacMiddleClick.xcodeproj`。
2. 选择 `MacMiddleClick` scheme 并运行。
3. 尚未授权时，应用会先说明操作方法；点击“好，去授权”后，在 macOS 系统提示中打开“系统设置 → 隐私与安全性 → 辅助功能”，允许 MacMiddleClick。
4. 回到任意应用，按住 `Fn` 后点击或拖动。

应用只显示在菜单栏，不显示 Dock 图标。授权、启用和禁用合并在同一个动态菜单项中：

- 未授权：`Fn + 左键 → 中键：点击启用`
- 已启用：`Fn + 左键 → 中键：已启用`
- 已禁用：`Fn + 左键 → 中键：已禁用`

禁用状态不会保存。重新启动应用或从菜单重新请求授权时，都会默认启用映射。

## 测试

在 Xcode 中选择 `MacMiddleClick` scheme 后按 `⌘U`，或者运行：

```sh
xcodebuild \
  -project MacMiddleClick.xcodeproj \
  -scheme MacMiddleClick \
  -destination 'platform=macOS,arch=arm64' \
  test
```

单元测试覆盖 Fn 点击状态机、完整中键拖动序列、事件字段改写、修饰键处理以及事件监听被系统重置后的恢复状态。创建真实的全局 Event Tap 仍需要在实际应用运行时授予辅助功能权限，因此不在无权限的单元测试进程中执行。

## 技术实现

- `CGEventTap` 监听左键按下、拖动和释放。
- 检查公开的 `CGEventFlags.maskSecondaryFn` 标记。
- 将事件改写为 `otherMouseDown`、`otherMouseDragged`、`otherMouseUp`，并把按钮号设置为 2。
- 使用 `AXIsProcessTrusted` 请求事件改写所需的辅助功能权限。

不使用 `MultitouchSupport.framework` 或其他私有 API。
