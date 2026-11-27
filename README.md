# MATLAB Figure Pack

Turn a folder of saved MATLAB `.fig` files into a bundle your team can review in a browser, paste into a report, or reuse in Excel and Python. Run one command to get an offline gallery, report graphics, and the XY samples from supported line plots.

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=lenguoyu/matlab-lab-figure-export&file=demo_lab_figure_pack.m) · [Download ZIP](https://github.com/lenguoyu/matlab-lab-figure-export/archive/refs/heads/main.zip) · [中文用法](#中文用法)

![Output preview showing two generated MATLAB figures, a 50 Hz signal and a two-panel RC filter response.](figure-pack-preview.png)

## Try it with two example figures

Open the repository folder as your current MATLAB folder or add it to the MATLAB path. Run the demo to generate the figures and a complete pack. The demo uses synthetic data and reports the path to `index.html`.

```matlab
[report, folder] = demo_lab_figure_pack('figure-pack-demo');
```

Open `figure-pack-demo/figure-pack/index.html` in your browser. In MATLAB Online, download the output folder to view the gallery with its assets. Omit the folder argument to generate a new temporary demo on each run.

## Build a pack from your own figures

```matlab
plan = export_lab_batch('experiment-figs', 'figure-pack', 'DryRun', true);
report = export_lab_batch('experiment-figs', 'figure-pack', 'DPI', 450);
```

The dry run lists planned files without loading figures or writing output. The export scans subfolders in path order and writes a fresh destination folder. It expects one MATLAB figure per `.fig` file. The returned table shows the status of each input. The manifest records any files that fail to load or render while the batch continues to the next file.

```text
figure-pack/
├── index.html             Offline gallery with per-figure links
├── manifest.csv           Input paths, output paths, page numbers, and errors
├── figures.pdf            One page per successful figure, in path order
└── plots/
    ├── 01-signals/
    │   ├── sine-traces.png
    │   ├── sine-traces.pdf
    │   └── sine-traces.csv
    └── 02-response/
        ├── rc-low-pass.png
        ├── rc-low-pass.pdf
        └── rc-low-pass.csv
```

Batch options are `DPI` (450 by default), `DryRun` (false), and `CombinePDF` (true). The book includes every successful figure. Set `'CombinePDF', false` to export the individual files and gallery only. The gallery loads its plots from the `plots/` folder. Share the entire pack to keep the links usable.

## Reuse the data behind a plot

The CSV contains the values stored by MATLAB's visible, two-dimensional numeric line objects on Cartesian axes, including axes in tiled figures. Each row identifies its axes, series, and sample. Lines can have different sampling grids, and NaN gaps stay in the sequence. Labels use the line's `DisplayName` when available. A figure such as a scatter plot still gets graphic files and a gallery card, with no line-data CSV. The extractor leaves the Y-axis units blank for dual-Y axes.

```matlab
samples = extract_lab_figure_data(gca);
writetable(samples, 'trace.csv', 'Encoding', 'UTF-8');
```

To export one open plot as PNG and PDF, use `export_lab_figure(gca, 'response')`. Pass a third argument to change the PNG resolution. The single-figure helper also accepts a figure handle or a `tiledlayout` handle.

## Requirements

Batch export uses base MATLAB R2021b or later and was tested in R2024b. The single-figure helper supports R2020a or later. Use `.fig` files from sources you trust because MATLAB can execute code as it loads graphics objects. [MathWorks `openfig` documentation](https://www.mathworks.com/help/matlab/ref/openfig.html)

The automated checks exercise nested files, invalid input, unequal sample grids, output conflicts, links with special characters, and optional PDF aggregation.

```matlab
assertSuccess(runtests('test_export_lab_batch.m'));
```

## 中文用法

把 MATLAB 实验目录里的 `.fig` 一次整理成可交付的图表包。打开 `index.html` 可以浏览图片，逐图下载 PNG、矢量 PDF 和可提取的曲线 CSV。`manifest.csv` 记录每张图的结果、失败原因和 PDF 页码。数据 CSV 保存图上已有的 XY 样本，适合在 Excel 或 Python 里重画。

```matlab
demo_lab_figure_pack('figure-pack-demo');
report = export_lab_batch('实验图目录', '交付图包');
```

默认递归处理，PNG 为 450 DPI，并生成合并后的 `figures.pdf`。目标目录需是新目录。加 `'DryRun', true` 可以先看处理清单。批处理需要 MATLAB R2021b 或以上版本，已在 R2024b 实测。

## License

[MIT](LICENSE)
