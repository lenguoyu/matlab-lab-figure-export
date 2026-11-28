# One-command handoff · 一键交付包

用 `build_lab_delivery` 把保存的 MATLAB 图、图稿预检和选定的项目文件打成一个 ZIP。解包后打开根目录的 `index.html`，可查看逐图状态、打开图集、下载清单或找到报告和代码。

## 生成交付包

在 MATLAB 中将仓库根目录加入路径。这个例子从 `experiment-figs` 导出图，从 `coursework` 选择一份脚本和一份 PDF，并按 88.9 mm 的放置宽度检查 PNG 是否达到 600 DPI。

```matlab
[archive, summary] = build_lab_delivery('experiment-figs', 'lab-handoff.zip', 88.9, 600, ...
    'AttachmentRoot', 'coursework', ...
    'Files', ["code/main.m", "reports/lab.pdf"]);
```

输出使用一个新的 `.zip` 路径，父目录需已存在。`Files` 接受单个路径或路径列表，保留相对于 `AttachmentRoot` 的子目录，其中的代码、报告和数据按原文件内容复制。省略 `Files` 时交付包只包含生成的文件。脚本所需的其他 `.m`、`.mlx` 或数据可逐个加入列表。MATLAB 会加载 `experiment-figs` 内的 `.fig`，请只使用可信的图文件。 [MathWorks `openfig`](https://www.mathworks.com/help/matlab/ref/openfig.html)

默认以 450 DPI 导出 PNG，并附合并的 PDF 图册。用 `'DPI', 600` 调整导出设置，或用 `'CombinePDF', false` 仅保留逐图 PDF。预检按 PNG 实际像素宽度和指定的放置宽度计算有效 DPI。导出失败和分辨率不足会写入报告，交付前可在 `index.html` 查看。

### 选择图稿

如果图已经在 MATLAB 中打开，可以直接传入有效的图窗句柄。顺序决定图集中的编号和合并 PDF 的页序，交付后图窗仍保持打开。`figure-0001` 等编号按传入顺序生成。要用 `compare_lab_packs` 对比两轮结果，按相同顺序传入对应的图窗。

```matlab
archive = build_lab_delivery([figA, figB], 'open-figures.zip', 88.9, 600);
```

也可以从一批保存的图中挑选本次需要的文件。`FigureFiles` 至少要列出一条相对于图稿目录的 `.fig` 路径，按列出的顺序导出。省略此选项会扫描图稿目录及其子目录。`Files` 用于指定代码、报告和其他附件。只需要导出图稿时，`export_lab_batch` 也接受图窗句柄和 `FigureFiles`。

```matlab
archive = build_lab_delivery('experiment-figs', 'paper-figures.zip', 88.9, 600, ...
    'FigureFiles', ["results/step.fig", "results/residual.fig"]);
```

## 加入离线交互图

需要浏览器缩放和查点时，保存官方 Plotly.js Basic 文件和同版本 MIT 许可证。运行命令时提供两者的本地路径。二维数值折线支持交互查看，其他成功导出的图可显示 PNG 预览。 [Plotly Basic v4.2.0](https://cdn.plot.ly/plotly-basic-4.2.0.min.js) · [同版本 MIT 许可](https://raw.githubusercontent.com/plotly/plotly.js/v4.2.0/LICENSE) · [数据范围说明](INTEGRATIONS.md)

```matlab
[archive, summary] = build_lab_delivery('experiment-figs', 'lab-interactive.zip', 88.9, 600, ...
    'AttachmentRoot', 'coursework', ...
    'Files', ["code/main.m", "reports/lab.pdf"], ...
    'PlotlyJS', 'plotly-basic-4.2.0.min.js', ...
    'PlotlyLicense', 'LICENSE');
```

## 解包后提交所需文件

| 归档路径 | 内容 |
| --- | --- |
| `index.html` | 交付入口、逐图状态、预检结果和附件链接 |
| `artwork-check.csv` | PNG 像素、实际 DPI、阈值及待复核项 |
| `figures/` | 离线图集、导出清单、逐图 PNG/PDF 和可用的 XY CSV |
| `attachments/` | 所选文件及其相对目录结构 |
| `interactive/` | 可选的离线交互图集、本地渲染器和许可 |
| `delivery-manifest.csv` | 文件相对路径、用途和字节数，清单自身除外 |

- **课程作业。** MIT 的一份作业指南要求把 MATLAB 文件和 PDF 装入 ZIP。CMU 的一个实例将作业 PDF 和 `.m` 文件分开提交。遇到分开收件的课程，从解包目录取出要求的文件。 [MIT 课程指南](https://ocw.mit.edu/courses/10-34-numerical-methods-applied-to-chemical-engineering-fall-2015/e5f1841a841b5910a3d250dcca7b9221_MIT10_34F15_HW_Guide_2015.pdf) · [CMU 作业说明](https://course.ece.cmu.edu/~ece491/homework/h5.pdf#page=5)
- **论文。** Nature 的首轮投稿说明偏好将正文和图放在同一个文件，终稿流程则可要求单独上传图。从 `figures/plots/` 取出逐图文件，并按需要随包提供绘图代码和支撑结论的原始数据。图包的 XY CSV 只包含支持导出的折线样本。 [Nature 首轮投稿](https://www.nature.com/nature/for-authors/initial-submission) · [Nature 终稿说明](https://www.nature.com/nature/for-authors/final-submission) · [PLOS 数据可用性政策](https://journals.plos.org/plosone/s/data-availability)
