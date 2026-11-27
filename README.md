# MATLAB Figure Pack

Turn saved MATLAB `.fig` files into a shareable figure pack, then compare two runs in your browser. The pack contains report graphics and XY samples. The comparison report pairs the figures and shows which saved curves changed, where the largest difference occurs, and which files need review.

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=lenguoyu/matlab-lab-figure-export&file=demo_lab_pack_comparison.m) · [Download source](https://github.com/lenguoyu/matlab-lab-figure-export/archive/refs/heads/main.zip) · [Offline example](https://github.com/lenguoyu/matlab-lab-figure-export/raw/refs/heads/main/comparison-example.zip) · [中文用法](#中文用法)

![Baseline and candidate plots for a controller change, with the maximum absolute difference marked in the comparison summary.](comparison-preview.png)

## Compare two runs

The offline example contains the actual demo report. Unzip it and open `index.html` to try the status filters in your browser.

Open the repository folder in MATLAB and run the demo. It builds two synthetic figure packs and plants a step-response change, a different sampling grid, a removed figure, and an added figure.

```matlab
[figures, series, folder] = demo_lab_pack_comparison('comparison-demo');
```

Open `comparison-demo/comparison/index.html` in a browser. Filter by status, review side-by-side PNGs, and expand the metrics for each line. For your own runs, pass the two figure pack folders to the same comparison function.

```matlab
[figures, series] = compare_lab_packs('baseline-pack', 'candidate-pack', ...
    'comparison', 'AbsTol', 0.015, 'RelTol', 0.02);
```

`comparison.csv` gives one row per source figure. `series.csv` gives one row per line series with sample counts, maximum absolute Y difference, and its X coordinate. The report stores its own PNG previews, so you can share the `comparison/` folder by itself. In MATLAB Online, download the folder before opening the HTML locally.

### What the comparison measures

Figures pair by exact source path relative to their original input folders. Within each figure, the report pairs equal axes and series IDs and checks their labels and axis metadata. A series is compared in saved sample order when the X coordinates match, including repeated or decreasing coordinates. Changed grids, metadata, and missing series are shown for review. The reports can also show PNGs for figures without line CSVs.

For each finite paired sample, the tolerance is `max(AbsTol, RelTol * abs(baselineY))`. Both options default to zero. `AbsTol` uses the plotted Y units and applies to every series. A difference equal to the tolerance passes. Shared gaps are skipped and changed gaps are flagged. The result describes the stored XY samples. Read per-series differences with the axis units in the previews, which also help with layout, marker, and color review.

## Export a folder of figures

![Output preview showing a 50 Hz signal and a two-panel RC filter response with PNG, PDF, and XY CSV outputs.](figure-pack-preview.png)

### Try it with two example figures

Open the repository folder as your current MATLAB folder or add it to the MATLAB path. Run the demo to generate the figures and a complete pack. The demo uses synthetic data and reports the path to `index.html`.

```matlab
[report, folder] = demo_lab_figure_pack('figure-pack-demo');
```

Open `figure-pack-demo/figure-pack/index.html` in your browser. In MATLAB Online, download the output folder to view the gallery with its assets. Omit the folder argument to generate a new temporary demo on each run.

### Build a pack from your own figures

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

The automated checks exercise nested figure exports, data recovery, portable reports, tolerance boundaries, grid and gap changes, and invalid artifact paths.

```matlab
assertSuccess(runtests('test_export_lab_batch.m'));
assertSuccess(runtests('test_compare_lab_packs.m'));
```

## 中文用法

把 MATLAB 实验目录里的 `.fig` 整理成图表包，也能比较基线和新一轮的图包。双栏报告可离线查看，并按状态筛选。曲线表记录超差点数、最大绝对偏差及所在横坐标。采样网格或曲线身份变动时，报告会标记需要复核。

```matlab
demo_lab_pack_comparison('comparison-demo');
report = export_lab_batch('实验图目录', '交付图包');
[figures, series] = compare_lab_packs('基准图包', '本次图包', '对比结果');
```

演示结果位于 `comparison-demo/comparison/index.html`。图包默认递归处理，生成 450 DPI PNG、逐图和合并的矢量 PDF，以及可提取的曲线 CSV。加 `'DryRun', true` 可以先看处理清单。运行需要 MATLAB R2021b 或以上版本，已在 R2024b 实测。

## License

[MIT](LICENSE)
