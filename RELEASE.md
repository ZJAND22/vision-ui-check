# v0.1.0 — 让 AI "看见" UI 的工具包

## 这是什么

`vision-ui-check` 是一个 Windows 小工具包：**给程序窗口截图（含 Unity IMGUI），生成标注图与客观指标，交给视觉模型评审**。
解决的是"AI 改 UI 时看不到结果、只能盲改"的问题。

## 包含

| 文件 | 作用 |
|---|---|
| `capture_window.ps1` | 启动/定位窗口，DPI 感知，`PrintWindow` 抓 D3D 画面，白屏检测，裁成客户区 |
| `shot_review.py` | 生成九宫格标注图 + 指标报告（清晰度/亮度/左右均衡/贴边） |
| `ui_shot.ps1` | 一条命令完成"截图 + 审查" |
| `vision_prompt.md` | 4 套给视觉模型的提示词模板（通用体检/查糊/改版对比/对齐） |

## 快速开始

```powershell
pip install pillow numpy

# 截图 + 审查
.\ui_shot.ps1 -ExePath "C:\path\YourGame.exe" -OutDir ".\shots"

# 直接进入某个界面（游戏支持命令行参数时）
.\ui_shot.ps1 -ExePath "...\YourGame.exe" -GameArgs "-prologue" -Name prologue
```

输出：

```
shots/ui_prologue_155237.png           实机截图 1280x720
shots/ui_prologue_155237_annot.png     标注图（九宫格 + 每格清晰度）
shots/ui_prologue_155237_report.md     指标报告
```

## 本版修掉的问题（开发过程中的真实坑）

1. **batch 抓不到 IMGUI** → 改用 Win32 `PrintWindow(PW_RENDERFULLCONTENT)` 抓整个窗口；
2. **抓到白屏** → 加"取帧就绪检测"（连抓 25 次直到画面标准差 > 12）；
3. **抓到别的窗口**（D3D 窗口被遮挡时 BitBlt 回退到桌面）→ 优先 `PrintWindow`，失败才 BitBlt；
4. **画面被裁**（窗口比客户区高 56px）→ 先读实际窗口/客户区尺寸，按 `barH` 裁标题栏；
5. **中文路径脚本报错**（PowerShell 5.1 需要 BOM）→ 所有 `.ps1` 存为 UTF-8 BOM；
6. **DPI 缩放导致布局与截图不一致** → `SetProcessDPIAware()`。

## 已知限制

- 只抓整窗，没有控件树；
- 个别驱动下 `PrintWindow` 可能返回黑图；
- 指标只能发现"糊/失衡/贴边"，"好不好看"仍需视觉模型或人。

## 下一步

- [ ] Linux/macOS 支持（`xwd` / `screencapture`）
- [ ] 元素级裁剪（按坐标区域单独导出，便于模型细看）
- [ ] 与 CI 集成（截图 diff 回归）

## License

MIT
