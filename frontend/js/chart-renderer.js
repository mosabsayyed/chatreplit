/**
 * ChartRenderer - Renders interactive charts using Highcharts
 * Supports: spider/radar, bubble, bullet, combo, column, line charts
 */

class ChartRenderer {
    constructor(containerId) {
        this.containerId = containerId;
        this.currentChart = null;
    }
    
    static highchartsPromise = null;
    
    static loadHighcharts() {
        if (ChartRenderer.highchartsPromise) {
            return ChartRenderer.highchartsPromise;
        }
        
        if (typeof Highcharts !== 'undefined') {
            ChartRenderer.highchartsPromise = Promise.resolve();
            return ChartRenderer.highchartsPromise;
        }
        
        ChartRenderer.highchartsPromise = new Promise((resolve, reject) => {
            const baseScript = document.createElement('script');
            baseScript.src = 'https://code.highcharts.com/highcharts.js';
            baseScript.onload = () => {
                const moreScript = document.createElement('script');
                moreScript.src = 'https://code.highcharts.com/highcharts-more.js';
                moreScript.onload = () => {
                    const exportingScript = document.createElement('script');
                    exportingScript.src = 'https://code.highcharts.com/modules/exporting.js';
                    exportingScript.onload = () => {
                        const bulletScript = document.createElement('script');
                        bulletScript.src = 'https://code.highcharts.com/modules/bullet.js';
                        bulletScript.onload = () => resolve();
                        bulletScript.onerror = () => {
                            ChartRenderer.highchartsPromise = null;
                            reject(new Error('Failed to load Highcharts bullet module'));
                        };
                        document.head.appendChild(bulletScript);
                    };
                    exportingScript.onerror = () => {
                        ChartRenderer.highchartsPromise = null;
                        reject(new Error('Failed to load Highcharts exporting module'));
                    };
                    document.head.appendChild(exportingScript);
                };
                moreScript.onerror = () => {
                    ChartRenderer.highchartsPromise = null;
                    reject(new Error('Failed to load Highcharts more module'));
                };
                document.head.appendChild(moreScript);
            };
            baseScript.onerror = () => {
                ChartRenderer.highchartsPromise = null;
                reject(new Error('Failed to load Highcharts'));
            };
            document.head.appendChild(baseScript);
        });
        
        return ChartRenderer.highchartsPromise;
    }
    
    async render(artifact) {
        const container = document.getElementById(this.containerId);
        if (!container) {
            console.error(`Container ${this.containerId} not found`);
            return;
        }
        
        if (this.currentChart) {
            this.currentChart.destroy();
            this.currentChart = null;
        }
        
        const chartData = artifact.content;
        const chartContainerId = `chart-${Date.now()}`;
        
        container.innerHTML = `
            <div class="artifact-container">
                <div class="artifact-header">
                    <div class="artifact-title-main">${artifact.title}</div>
                    <div class="artifact-meta-row">
                        <div class="artifact-meta-item">
                            <span>📊</span>
                            <span>Chart Type: ${this.getChartTypeLabel(chartData.type)}</span>
                        </div>
                        <div class="artifact-meta-item">
                            <span>📅</span>
                            <span>Created: ${new Date(artifact.created_at).toLocaleDateString()}</span>
                        </div>
                    </div>
                    <div class="artifact-actions">
                        <button class="export-btn" onclick="chartRenderer.exportChart('png')">📥 Export PNG</button>
                        <button class="export-btn secondary" onclick="chartRenderer.exportChart('svg')">📥 Export SVG</button>
                    </div>
                </div>
                <div class="chart-container" id="${chartContainerId}" style="min-height: 500px;">
                    <div class="canvas-loading">
                        <div class="canvas-loading-spinner"></div>
                        <div style="margin-top: 10px;">Loading Highcharts...</div>
                    </div>
                </div>
                ${chartData.description ? `<div class="chart-description">${chartData.description}</div>` : ''}
            </div>
        `;
        
        try {
            await ChartRenderer.loadHighcharts();
            this.renderChart(chartData, chartContainerId);
        } catch (error) {
            console.error('Failed to load Highcharts:', error);
            const chartContainer = document.getElementById(chartContainerId);
            if (chartContainer) {
                chartContainer.innerHTML = `
                    <div class="canvas-empty">
                        <div class="canvas-empty-icon">⚠️</div>
                        <div class="canvas-empty-text">Failed to load chart library</div>
                    </div>
                `;
            }
        }
    }
    
    renderChart(chartData, containerId) {
        const chartConfig = this.buildChartConfig(chartData);
        this.currentChart = Highcharts.chart(containerId, chartConfig);
    }
    
    buildChartConfig(chartData) {
        const baseConfig = {
            chart: {
                type: chartData.type || 'column',
                backgroundColor: '#ffffff',
                style: {
                    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
                }
            },
            title: {
                text: chartData.chart_title || '',
                style: {
                    fontSize: '20px',
                    fontWeight: '600',
                    color: '#1a1a1a'
                }
            },
            subtitle: {
                text: chartData.subtitle || '',
                style: {
                    fontSize: '14px',
                    color: '#666'
                }
            },
            credits: {
                enabled: false
            },
            exporting: {
                buttons: {
                    contextButton: {
                        enabled: false
                    }
                }
            },
            series: chartData.series || []
        };
        
        switch(chartData.type) {
            case 'radar':
            case 'spider':
                return this.buildRadarConfig(chartData, baseConfig);
            case 'bubble':
                return this.buildBubbleConfig(chartData, baseConfig);
            case 'bullet':
                return this.buildBulletConfig(chartData, baseConfig);
            case 'column':
                return this.buildColumnConfig(chartData, baseConfig);
            case 'line':
                return this.buildLineConfig(chartData, baseConfig);
            case 'combo':
                return this.buildComboConfig(chartData, baseConfig);
            default:
                return this.buildColumnConfig(chartData, baseConfig);
        }
    }
    
    buildRadarConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            chart: {
                ...baseConfig.chart,
                polar: true,
                type: 'line'
            },
            pane: {
                size: '80%'
            },
            xAxis: {
                categories: chartData.categories || [],
                tickmarkPlacement: 'on',
                lineWidth: 0
            },
            yAxis: {
                gridLineInterpolation: 'polygon',
                lineWidth: 0,
                min: 0,
                max: chartData.max_value || 5
            },
            tooltip: {
                shared: true,
                pointFormat: '<span style="color:{series.color}">{series.name}: <b>{point.y}</b><br/>'
            },
            legend: {
                align: 'center',
                verticalAlign: 'bottom',
                layout: 'horizontal'
            },
            series: chartData.series
        };
    }
    
    buildBubbleConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            chart: {
                ...baseConfig.chart,
                type: 'bubble',
                plotBorderWidth: 1,
                zoomType: 'xy'
            },
            xAxis: {
                title: {
                    text: chartData.x_axis_label || 'X Axis'
                },
                gridLineWidth: 1
            },
            yAxis: {
                title: {
                    text: chartData.y_axis_label || 'Y Axis'
                }
            },
            tooltip: {
                useHTML: true,
                headerFormat: '<table>',
                pointFormat: '<tr><th colspan="2"><h3>{point.name}</h3></th></tr>' +
                    '<tr><th>{series.xAxis.axisTitle.textStr}:</th><td>{point.x}</td></tr>' +
                    '<tr><th>{series.yAxis.axisTitle.textStr}:</th><td>{point.y}</td></tr>' +
                    '<tr><th>Size:</th><td>{point.z}</td></tr>',
                footerFormat: '</table>',
                followPointer: true
            },
            plotOptions: {
                bubble: {
                    minSize: 20,
                    maxSize: 80
                }
            },
            series: chartData.series
        };
    }
    
    buildBulletConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            chart: {
                ...baseConfig.chart,
                type: 'bullet',
                inverted: true,
                marginLeft: 200,
                height: 80 * (chartData.series?.length || 1) + 100
            },
            xAxis: {
                categories: chartData.categories || []
            },
            yAxis: {
                plotBands: chartData.plot_bands || [],
                title: null
            },
            plotOptions: {
                bullet: {
                    pointPadding: 0.25,
                    borderWidth: 0,
                    color: '#667eea',
                    targetOptions: {
                        width: '200%',
                        color: '#333'
                    }
                }
            },
            tooltip: {
                pointFormat: '<b>{point.y}</b> (target: {point.target})'
            },
            series: chartData.series
        };
    }
    
    buildColumnConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            xAxis: {
                categories: chartData.categories || [],
                crosshair: true,
                title: {
                    text: chartData.x_axis_label || ''
                }
            },
            yAxis: {
                min: 0,
                title: {
                    text: chartData.y_axis_label || 'Values'
                }
            },
            tooltip: {
                headerFormat: '<span style="font-size:10px">{point.key}</span><table>',
                pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
                    '<td style="padding:0"><b>{point.y}</b></td></tr>',
                footerFormat: '</table>',
                shared: true,
                useHTML: true
            },
            plotOptions: {
                column: {
                    pointPadding: 0.2,
                    borderWidth: 0,
                    dataLabels: {
                        enabled: chartData.show_data_labels || false
                    }
                }
            },
            series: chartData.series
        };
    }
    
    buildLineConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            xAxis: {
                categories: chartData.categories || [],
                title: {
                    text: chartData.x_axis_label || ''
                }
            },
            yAxis: {
                title: {
                    text: chartData.y_axis_label || 'Values'
                }
            },
            tooltip: {
                shared: true,
                crosshairs: true
            },
            plotOptions: {
                line: {
                    dataLabels: {
                        enabled: chartData.show_data_labels || false
                    },
                    enableMouseTracking: true
                }
            },
            series: chartData.series
        };
    }
    
    buildComboConfig(chartData, baseConfig) {
        return {
            ...baseConfig,
            chart: {
                ...baseConfig.chart,
                type: undefined
            },
            xAxis: {
                categories: chartData.categories || [],
                crosshair: true,
                title: {
                    text: chartData.x_axis_label || ''
                }
            },
            yAxis: chartData.y_axes || [
                {
                    title: {
                        text: chartData.y_axis_label || 'Values'
                    }
                }
            ],
            tooltip: {
                shared: true
            },
            series: chartData.series
        };
    }
    
    async exportChart(format) {
        if (!this.currentChart) {
            alert('No chart to export');
            return;
        }
        
        try {
            await ChartRenderer.loadHighcharts();
            
            if (format === 'png') {
                this.currentChart.exportChart({
                    type: 'image/png',
                    filename: 'chart'
                });
            } else if (format === 'svg') {
                this.currentChart.exportChart({
                    type: 'image/svg+xml',
                    filename: 'chart'
                });
            }
        } catch (error) {
            console.error('Failed to export chart:', error);
            alert('Failed to export chart. Please try again.');
        }
    }
    
    getChartTypeLabel(type) {
        const labels = {
            'radar': 'Spider/Radar Chart',
            'spider': 'Spider/Radar Chart',
            'bubble': 'Bubble Chart',
            'bullet': 'Bullet Chart',
            'column': 'Column Chart',
            'line': 'Line Chart',
            'combo': 'Combo Chart'
        };
        return labels[type] || 'Chart';
    }
}

let chartRenderer;
document.addEventListener('DOMContentLoaded', () => {
    chartRenderer = new ChartRenderer('canvasContent');
});
