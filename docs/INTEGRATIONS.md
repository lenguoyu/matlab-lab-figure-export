# Plotly integration · 外部工具接入

Figure Pack uses the same saved XY CSVs for MATLAB replotting and for the optional Plotly adapter. Start with the [offline example ZIP](https://github.com/lenguoyu/matlab-lab-figure-export/raw/refs/heads/main/docs/plotly-example.zip), unzip it, and open `index.html` to inspect the demo traces in a browser.

## 1. 离线交互图册

将 [Plotly.js Basic v4.2.0](https://cdn.plot.ly/plotly-basic-4.2.0.min.js) 和 [同版本 MIT 许可](https://raw.githubusercontent.com/plotly/plotly.js/v4.2.0/LICENSE) 下载到本机。用已有的图包目录和一个新的输出目录运行下列命令。

```matlab
report = export_lab_plotly('figure-pack', 'browser-review', ...
    'PlotlyJS', 'plotly-basic-4.2.0.min.js', ...
    'PlotlyLicense', 'LICENSE');
```

打开 `browser-review/index.html`，用下拉框切换图。折线可以缩放、显示或隐藏，并用悬停查样本序号及坐标。Plotly 工具栏可保存当前图为 SVG，页面也可下载该图的 Plotly JSON。仅有图像预览的行可使用随包复制的 PNG。图册同时包含本地浏览器包和许可，分享时复制整个目录。

Plotly.js 使用图包 CSV 中保存的二维折线样本。坐标轴默认线性。需要正值对数轴时，传入 `'XScale', 'log'` 或 `'YScale', 'log'`。这些选项应用到本次输出的相应坐标轴。原始 MATLAB 样式、坐标布局和双 Y 轴可在可信的原 `.fig` 中查看。

## 2. 给 Python 或网页工具传图

省略浏览器包参数即可生成一图一个 JSON，并在 `plotly-manifest.csv` 中查看每张图的文件路径。这个入口只需要基础 MATLAB。

```matlab
report = export_lab_plotly('figure-pack', 'plotly-json');
disp(report(:, {'Source', 'Status', 'Artifact'}))
```

使用已安装的 Plotly.py 读取 `Artifact` 对应的文件。

```python
import plotly.io as pio

fig = pio.read_json("plotly-json/figures/0001.json")
fig.show()
```

Plotly.py 使用 JSON 中的曲线、子图和标签。若需要用 Matplotlib 重新排版，可以直接读图包中的 XY CSV，并按需采用 SciencePlots 的样式。Matplotlib 3.11 对应的兼容问题在 SciencePlots 2.2.2 中修复。 [Plotly.py JSON 接口](https://plotly.com/python-api-reference/generated/plotly.io.read_json.html) · [SciencePlots MIT 许可](https://github.com/garrettj403/SciencePlots/blob/master/LICENSE) · [兼容问题](https://github.com/garrettj403/SciencePlots/issues/163)

## 3. 如何选择交付物

论文交付按期刊要求准备矢量图、绘图代码和支持结果的源数据。浏览器预览适合在讨论中查图上的点。课程可以把交互图册作为补充资料，按课程说明另交 PDF 和 MATLAB 源文件。 [Nature 插图指南](https://research-figure-guide.nature.com/figures/preparing-figures-our-specifications/) · [PLOS 数据可用性政策](https://journals.plos.org/plosone/s/data-availability) · [CMU 课程实例](https://course.ece.cmu.edu/~ece491/homework/h5.pdf#page=5)

这个接入通过本地 Plotly.js 资源渲染，参考了社区对报告缩放和离线分享的需求。旧版 Plotly MATLAB 桥接器曾记录过 CDN 地址问题。随包保留固定版本的 MIT 许可和原样浏览器文件。 [社区缩放请求](https://www.mathworks.com/matlabcentral/answers/1810090-zoomable-plots-in-html-reports) · [上游离线问题记录](https://github.com/plotly/plotly_matlab/issues/526) · [官方 Basic 包说明](https://github.com/plotly/plotly.js/blob/v4.2.0/dist/README.md#plotlyjs-basic)
