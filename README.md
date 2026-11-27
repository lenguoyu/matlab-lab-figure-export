# MATLAB Figure Pack

Turn saved MATLAB figures into a shareable bundle with an offline gallery, PNG and vector PDF exports, and reusable XY data. Use the same bundle to compare runs, preflight paper artwork, rebuild editable plots, or connect to Plotly and Python.

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=lenguoyu/matlab-lab-figure-export&file=demo_lab_figure_pack.m) · [Download source](https://github.com/lenguoyu/matlab-lab-figure-export/archive/refs/heads/main.zip) · [Offline comparison example](https://github.com/lenguoyu/matlab-lab-figure-export/raw/refs/heads/main/comparison-example.zip) · [中文工作流](docs/WORKFLOWS.md)

![Side-by-side comparison of real MATLAB plots from the included synthetic controller demo.](comparison-preview.png)

## Try it

Set the repository as your current MATLAB folder, or add its root to the path. Generate two synthetic figures and open the gallery at `figure-pack-demo/figure-pack/index.html`.

```matlab
[report, pack] = demo_lab_figure_pack('figure-pack-demo');
```

| Task | MATLAB entry point |
| --- | --- |
| Export a folder of saved figures | `export_lab_batch('experiment-figs', 'figure-pack')` |
| Review two runs | `compare_lab_packs('baseline-pack', 'candidate-pack', 'comparison')` |
| Check a 600 DPI target at 88.9 mm | `check_lab_artwork(pack, 88.9, 600)` |
| Rebuild a saved curve as editable graphics | `replot_lab_figure(fullfile(pack, report.DataCSV(1)))` |
| Export Plotly JSON or an offline interactive gallery | `export_lab_plotly(pack, 'plotly-json')` · [Integration guide](docs/INTEGRATIONS.md) |
| Export one open figure | `export_lab_figure(gca, 'response')` |

The [workflow guide](docs/WORKFLOWS.md) shows how to prepare a paper figure, assemble coursework files, set a log axis, and interpret comparison results. To try the comparison from MATLAB, run `demo_lab_pack_comparison('comparison-demo')`. To browse the offline example, unzip it and open `index.html`.

Try the [interactive example ZIP](https://github.com/lenguoyu/matlab-lab-figure-export/raw/refs/heads/main/docs/plotly-example.zip) to zoom, inspect samples, and switch between charts in a browser.

## Requirements and tests

The workflows use base MATLAB R2021b or newer and are tested in R2024b. The standalone single-figure exporter works with R2020a or newer. Use trusted `.fig` files because MATLAB can execute code while loading graphics objects. [MathWorks `openfig` documentation](https://www.mathworks.com/help/matlab/ref/openfig.html)

```matlab
addpath(pwd);
assertSuccess(runtests('tests'));
```

The root contains the MATLAB entry points. Shared implementation lives in `private/`, workflows in `docs/`, and regression tests in `tests/`. [MIT License](LICENSE)
