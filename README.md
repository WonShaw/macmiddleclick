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

菜单中的自动启动选项会显示“开机后自动启动：已启用”或“开机后自动启动：已禁用”，点击即可切换。它使用 macOS 公开的登录项接口，首次运行时默认启用并尝试注册。启用后，MacMiddleClick 会在开机并进入桌面后自动运行。若系统需要用户批准，菜单会额外显示“需要在系统设置中允许自动启动…”，点击后打开“系统设置 → 通用 → 登录项”。用户主动禁用后，应用会记住该选择，不再尝试注册，也不会显示授权入口，直到用户重新启用。该设置与中键映射的临时启用/禁用状态相互独立。

## 使用提示与已知限制

- 部分 Mac 键盘将 `Fn` 标为 `🌐`。如果松开按键时出现输入法切换或表情符号面板，可前往“系统设置 → 键盘”，把“按下 Fn 键时”或“按下 🌐 键时”改为“无操作”。该设置的名称会随键盘型号和 macOS 版本变化。Apple 也在[键盘设置说明](https://support.apple.com/guide/mac-help/kbdm162/mac)中列出了此按键的可配置行为。
- MacMiddleClick 改写的是发送给目标应用的鼠标事件，不会改变物理设备的全局按钮状态。转换期间，`NSEvent.pressedMouseButtons` 或 `CGEventSource` 仍可能报告左键处于按下状态，而目标应用收到的是中键事件。绝大多数应用不受影响，但主动查询全局按钮状态的游戏、绘图或 CAD 软件可能出现不同表现。

## 测试

在 Xcode 中选择 `MacMiddleClick` scheme 后按 `⌘U`，或者运行：

```sh
xcodebuild \
  -project MacMiddleClick.xcodeproj \
  -scheme MacMiddleClick \
  -destination 'platform=macOS,arch=arm64' \
  test
```

单元测试覆盖 Fn 点击状态机、完整中键拖动序列、事件字段改写、修饰键处理、事件监听被系统重置后的恢复状态，以及登录项的注册、注销、等待批准和错误路径。测试使用模拟登录项服务，不会修改运行测试的 Mac。创建真实的全局 Event Tap 仍需要在实际应用运行时授予辅助功能权限，因此不在无权限的单元测试进程中执行。

## 技术实现

- `CGEventTap` 监听左键按下、拖动和释放。
- 检查公开的 `CGEventFlags.maskSecondaryFn` 标记。
- 将事件改写为 `otherMouseDown`、`otherMouseDragged`、`otherMouseUp`，并把按钮号设置为 2。
- 使用 `AXIsProcessTrusted` 请求事件改写所需的辅助功能权限。
- 在应用启动、用户打开菜单、前台应用切换，以及 Event Tap 被系统禁用时检查辅助功能权限并恢复事件监听；不使用定时轮询。
- 检查 Event Tap 的启用状态和 Mach Port 有效性，并在端口失效时通过回调清理旧监听、触发自动重建。
- 禁止同时运行多个 MacMiddleClick 实例，避免多个 Event Tap 重复处理输入。
- 使用 `SMAppService.mainApp` 注册或注销当前应用的登录项。

不使用 `MultitouchSupport.framework` 或其他私有 API。
