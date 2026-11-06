"""截图审查：把一张 UI 截图做成"带标注的检查图 + 指标报告"。

用法:
    python shot_review.py <shot.png> [--out-dir 目录]

输出:
    <shot>_annot.png   带九宫格参考线、1/3 分割线、区域指标的标注图
    <shot>_report.md   指标报告（清晰度 / 对比度 / 左右均衡 / 边界留白）
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def laplacian_var(gray):
    g = gray.astype(np.float32)
    lap = np.abs(np.gradient(np.gradient(g, axis=0), axis=0) + np.gradient(np.gradient(g, axis=1), axis=1))
    return float(lap.var())


def main():
    path = sys.argv[1]
    out_dir = None
    if "--out-dir" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--out-dir") + 1]
    out_dir = out_dir or os.path.dirname(path)
    os.makedirs(out_dir, exist_ok=True)

    im = Image.open(path).convert("RGB")
    a = np.array(im).astype(np.int16)
    h, w = a.shape[:2]
    gray = a.mean(axis=2)

    rows = []
    rows.append(f"# 截图审查：{os.path.basename(path)}")
    rows.append("")
    rows.append(f"- 尺寸：{w} x {h}")
    rows.append(f"- 全图清晰度（拉普拉斯方差）：{laplacian_var(gray):.1f}")
    rows.append(f"- 全图亮度：{gray.mean():.1f}（0-255）")
    rows.append("")
    rows.append("## 九宫格指标（清晰度 / 亮度）")
    rows.append("")
    rows.append("| 区 | 清晰度 | 亮度 | 标准差 |")
    rows.append("|---|---|---|---|")

    ann = im.copy()
    d = ImageDraw.Draw(ann)
    for r in range(3):
        for c in range(3):
            x0, x1 = c * w // 3, (c + 1) * w // 3
            y0, y1 = r * h // 3, (r + 1) * h // 3
            sub = gray[y0:y1, x0:x1]
            lv = laplacian_var(sub)
            rows.append(f"| r{r}c{c} | {lv:.1f} | {sub.mean():.1f} | {sub.std():.1f} |")
            d.rectangle([x0, y0, x1, y1], outline=(255, 80, 80), width=1)
            d.text((x0 + 6, y0 + 4), f"{lv:.0f}/{sub.mean():.0f}", fill=(255, 80, 80))

    rows.append("")
    rows.append("## 左右均衡（亮度）")
    rows.append("")
    left = gray[:, : w // 3].mean()
    mid = gray[:, w // 3: 2 * w // 3].mean()
    right = gray[:, 2 * w // 3:].mean()
    rows.append(f"- 左 {left:.1f} / 中 {mid:.1f} / 右 {right:.1f}")
    rows.append(f"- 左右差：{abs(left - right):.1f}（>25 说明画面明显失衡）")

    # 边缘留白：检查最外 2% 区域是否被内容顶死
    m = max(2, int(min(w, h) * 0.02))
    border_mean = np.concatenate([gray[:m, :].ravel(), gray[-m:, :].ravel(),
                                  gray[:, :m].ravel(), gray[:, -m:].ravel()]).mean()
    rows.append("")
    rows.append(f"- 边缘 2% 平均亮度：{border_mean:.1f}（用于判断 UI 是否贴边被裁）")

    d.line([(w // 2, 0), (w // 2, h)], fill=(80, 200, 255), width=1)
    d.line([(0, h // 2), (w, h // 2)], fill=(80, 200, 255), width=1)

    ann_path = os.path.join(out_dir, os.path.splitext(os.path.basename(path))[0] + "_annot.png")
    ann.save(ann_path)
    rep_path = os.path.join(out_dir, os.path.splitext(os.path.basename(path))[0] + "_report.md")
    with open(rep_path, "w", encoding="utf-8") as f:
        f.write("\n".join(rows))

    print("annot ->", ann_path)
    print("report ->", rep_path)
    print("\n".join(rows[-6:]))


if __name__ == "__main__":
    main()
