# vision-ui-check

> 给"看不见屏幕"的 AI（或人）用的 **UI 截图 + 体检** 小工具包。
> 一条命令：启动游戏 → 截图（含 IMGUI）→ 生成标注图 + 指标报告 → 交给视觉模型判断。

适用于 **Unity（含 IMGUI/UGUI）** 的 Windows 独立包；原理是 Win32 `PrintWindow`，能抓到 D3D 渲染 + IMGUI 的画面。

## 它解决什么问题

AI 改 UI 时常见的死循环：改代码 → 看不到结果 → 靠猜 → 越改越糊。
本工具让 AI 能：

- 拿到**实机截图**（不是 batch 渲染，IMGUI 也能抓到）；
- 拿到**客观指标**：清晰度（拉普拉斯方差）、亮度、左右均衡、边缘贴边、区域标注；
- 把图丢给视觉模型，按"位置 + 问题 + 建议"逐条评审；
- 改完再跑一次，形成**闭环**。

## 环境要求

- Windows 10/11
- Windows PowerShell 5.1（系统自带）或 PowerShell 7
- Python 3.9+，装 `Pillow`、`numpy`：`pip install pillow numpy`
- 被截图的程序有自己的窗口（不是全屏独占）

## 安装

```powershell
git clone <this repo> vision-ui-check
cd vision-ui-check
pip install pillow numpy
```

## 用法

```powershell
# 1) 启动游戏并截图（含 UI），再生成审查图/报告
.\ui_shot.ps1 -ExePath "C:\path\to\YourGame.exe" -OutDir ".\shots"

# 2) 想让游戏直接进入某个界面：传命令行参数
.\ui_shot.ps1 -ExePath "C:\path\to\YourGame.exe" -GameArgs "-prologue" -Name prologue

# 3) 只截图（不跑审查）
.\capture_window.ps1 -ExePath "C:\path\to\YourGame.exe" -Out ".\shots\shot.png"

# 4) 只审查一张已有截图
python shot_review.py ".\shots\shot.png" --out-dir ".\shots"
```

输出：

```
shots/
├── ui_<name>_<HHmmss>.png          原始截图（客户区，已裁掉标题栏）
├── ui_<name>_<HHmmss>_annot.png    标注图（九宫格 + 每格清晰度/亮度）
└── ui_<name>_<HHmmss>_report.md    指标报告（清晰度/亮度/左右均衡/贴边）
```

## 把图交给视觉模型

`vision_prompt.md` 里有可直接复制的提示词。核心是让模型按 **位置 + 问题 + 建议** 输出，并明确"只评价 UI，不评价玩法"。

## 工作流（推荐）

1. 跑 `ui_shot.ps1` → 得到实机图；
2. 视觉模型评审 → 得到问题列表；
3. 改代码；
4. 再跑一次 → 对比"改前/改后"，确认问题消失且没引入新问题。

本项目就是靠这个循环，把"按钮发虚/文字被裁/元素重叠"这类问题从 8 轮压到 1~2 轮。

## 已知限制

- 只抓**整个窗口**，没有控件树，无法精确到"某个按钮"（可用截图坐标反推）；
- 个别显卡/驱动下 `PrintWindow` 可能返回黑图 → 脚本会回退到 `BitBlt`；
- 截图尺寸取决于窗口客户区；游戏若用非整数 DPI 缩放，UI 布局可能与截图有偏差（脚本已做 DPI 感知）；
- 指标只能发现"糊/失衡/贴边"，"好不好看"仍需视觉模型或人判断。

## 文件说明

| 文件 | 作用 |
|---|---|
| `capture_window.ps1` | 启动/定位窗口 → 等画面就绪 → 抓客户区 PNG |
| `shot_review.py` | 生成标注图 + 指标报告 |
| `ui_shot.ps1` | 一键：截图 + 审查 |
| `vision_prompt.md` | 给视觉模型的提示词模板 |

## License

MIT

## 自检（不依赖 CI）

```powershell
.\check.ps1
```

做三件事：Python 语法检查、PowerShell 脚本解析、用 `examples/prologue.png` 跑一遍审查脚本。
等价于 CI 的检查项，本地就能跑，不需要 GitHub 的 `workflow` 权限。

## 示例输出

`examples/` 里有对一张 1280×720 游戏菜单截图跑出来的结果：

- `supertuxkart_menu.png` — 原图（来源与授权见 `examples/CREDITS.md`）
- `supertuxkart_menu_annot.png` — 标注图（九宫格 + 每格清晰度/亮度）
- `supertuxkart_menu_report.md` — 指标报告
