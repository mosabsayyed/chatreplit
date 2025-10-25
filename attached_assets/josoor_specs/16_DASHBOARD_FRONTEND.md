# 16: DASHBOARD FRONTEND COMPONENT

```yaml
META:
  version: 1.0
  status: EXTRACTED_FROM_EXISTING_SPEC
  priority: HIGH
  dependencies: [15_DASHBOARD_BACKEND, 12_CHAT_INTERFACE_FRONTEND]
  implements: React dashboard with Highcharts visualizations
  file_location: frontend/src/components/Dashboard/
```

---

## **7\. FRONTEND DASHBOARD COMPONENT (React \+ TypeScript)**

### **7.1 Frontend Project Structure**

frontend/  
├── public/  
│   └── index.html  
├── src/  
│   ├── App.tsx  
│   ├── index.tsx  
│   ├── types/  
│   │   ├── dashboard.types.ts  
│   │   └── api.types.ts  
│   │  
│   ├── components/  
│   │   ├── Dashboard/  
│   │   │   ├── Dashboard.tsx              \# Main dashboard container  
│   │   │   ├── Zone1Health.tsx            \# Spider chart  
│   │   │   ├── Zone2Insights.tsx          \# Bubble chart  
│   │   │   ├── Zone3Outputs.tsx           \# Bullet charts  
│   │   │   ├── Zone4Outcomes.tsx          \# Combo chart  
│   │   │   └── LoadingState.tsx  
│   │   │  
│   │   ├── DrillDown/  
│   │   │   ├── DrillDownPanel.tsx         \# Slide-in panel  
│   │   │   ├── DrillDownContent.tsx       \# Content renderer  
│   │   │   ├── VisualizationGallery.tsx   \# Image carousel  
│   │   │   └── RelatedEntities.tsx        \# Entity list  
│   │   │  
│   │   ├── Chat/  
│   │   │   ├── ChatInterface.tsx          \# Q\&A chat  
│   │   │   ├── ChatMessage.tsx  
│   │   │   └── ChatInput.tsx  
│   │   │  
│   │   └── Common/  
│   │       ├── ConfidenceBadge.tsx  
│   │       ├── Breadcrumbs.tsx  
│   │       └── ContextMenu.tsx  
│   │  
│   ├── services/  
│   │   ├── api.service.ts                 \# API client  
│   │   └── analytics.service.ts           \# Event tracking  
│   │  
│   ├── hooks/  
│   │   ├── useDashboard.ts  
│   │   ├── useDrillDown.ts  
│   │   └── useChat.ts  
│   │  
│   ├── store/  
│   │   └── dashboardStore.ts              \# Zustand store  
│   │  
│   ├── utils/  
│   │   ├── chartHelpers.ts  
│   │   └── formatters.ts  
│   │  
│   └── styles/  
│       ├── globals.css  
│       └── dashboard.css  
│  
├── package.json  
├── tsconfig.json  
└── tailwind.config.js

### **7.2 TypeScript Type Definitions**

Copy  
// src/types/dashboard.types.ts  
export interface DimensionScore {  
  name: string;  
  score: number;  
  target: number;  
  description: string;  
  entity\_tables: string\[\];  
  trend: 'improving' | 'declining' | 'stable';  
}

export interface Zone1Data {  
  dimensions: DimensionScore\[\];  
  overall\_health: number;  
}

export interface BubblePoint {  
  id: number;  
  name: string;  
  x: number;  
  y: number;  
  z: number;  
  objective\_id: number;  
  project\_id: number;  
}

export interface Zone2Data {  
  bubbles: BubblePoint\[\];  
}

export interface MetricBar {  
  entity\_type: string;  
  current\_value: number;  
  target\_value: number;  
  performance\_percentage: number;  
}

export interface Zone3Data {  
  metrics: MetricBar\[\];  
}

export interface OutcomeMetric {  
  sector: string;  
  kpi\_name: string;  
  value: number;  
  target: number;  
  trend: number\[\];  
}

export interface Zone4Data {  
  outcomes: OutcomeMetric\[\];  
}

export interface DashboardData {  
  year: number;  
  quarter: string | null;  
  zone1: Zone1Data;  
  zone2: Zone2Data;  
  zone3: Zone3Data;  
  zone4: Zone4Data;  
  generated\_at: string;  
  cache\_hit: boolean;  
}

export interface DrillDownContext {  
  dimension?: string;  
  entity\_table?: string;  
  entity\_id?: number;  
  year: number;  
  quarter?: string;  
  level?: string;  
}

export interface DrillDownRequest {  
  zone: 'transformation\_health' | 'strategic\_insights' | 'internal\_outputs' | 'sector\_outcomes';  
  target: string;  
  context: DrillDownContext;  
}

export interface Visualization {  
  type: string;  
  title: string;  
  image\_base64: string;  
  description: string;  
}

export interface ConfidenceInfo {  
  level: 'high' | 'medium' | 'low';  
  score: number;  
  warnings: string\[\];  
}

export interface RelatedEntity {  
  entity\_type: string;  
  entity\_id: number;  
  entity\_name: string;  
  relationship: string;  
}

export interface DrillDownData {  
  narrative: string;  
  visualizations: Visualization\[\];  
  confidence: ConfidenceInfo;  
  related\_entities: RelatedEntity\[\];  
  recommended\_actions: string\[\];  
  metadata: Record\<string, any\>;  
}

### **7.3 API Service**

Copy  
// src/services/api.service.ts  
import axios, { AxiosInstance } from 'axios';  
import { DashboardData, DrillDownRequest, DrillDownData } from '../types/dashboard.types';

class ApiService {  
  private client: AxiosInstance;

  constructor() {  
    this.client \= axios.create({  
      baseURL: process.env.REACT\_APP\_API\_URL || 'http://localhost:8000/api/v1',  
      timeout: 60000, // 60 seconds for complex queries  
      headers: {  
        'Content-Type': 'application/json',  
      },  
    });  
  }

  async getDashboard(year: number, quarter?: string): Promise\<DashboardData\> {  
    const params \= { year, ...(quarter && { quarter }) };  
    const response \= await this.client.get\<DashboardData\>('/dashboard/generate', { params });  
    return response.data;  
  }

  async drillDown(request: DrillDownRequest): Promise\<DrillDownData\> {  
    const response \= await this.client.post\<DrillDownData\>('/dashboard/drill-down', request);  
    return response.data;  
  }

  async askAgent(question: string, context?: Record\<string, any\>): Promise\<any\> {  
    const response \= await this.client.post('/agent/ask', { question, context });  
    return response.data;  
  }

  async getHealthCheck(): Promise\<any\> {  
    const response \= await this.client.get('/health/check');  
    return response.data;  
  }  
}

export const apiService \= new ApiService();

### **7.4 Zustand Store**

Copy  
// src/store/dashboardStore.ts  
import { create } from 'zustand';  
import { DashboardData, DrillDownData } from '../types/dashboard.types';

interface DashboardStore {  
  // State  
  dashboardData: DashboardData | null;  
  drillDownData: DrillDownData | null;  
  loading: boolean;  
  error: string | null;  
  currentYear: number;  
  currentQuarter: string | null;  
  drillDownStack: string\[\]; // Breadcrumb trail  
    
  // Actions  
  setDashboardData: (data: DashboardData) \=\> void;  
  setDrillDownData: (data: DrillDownData) \=\> void;  
  setLoading: (loading: boolean) \=\> void;  
  setError: (error: string | null) \=\> void;  
  setCurrentYear: (year: number) \=\> void;  
  setCurrentQuarter: (quarter: string | null) \=\> void;  
  pushDrillDown: (target: string) \=\> void;  
  popDrillDown: () \=\> void;  
  clearDrillDown: () \=\> void;  
}

export const useDashboardStore \= create\<DashboardStore\>((set) \=\> ({  
  // Initial state  
  dashboardData: null,  
  drillDownData: null,  
  loading: false,  
  error: null,  
  currentYear: new Date().getFullYear(),  
  currentQuarter: null,  
  drillDownStack: \[\],  
    
  // Actions  
  setDashboardData: (data) \=\> set({ dashboardData: data }),  
  setDrillDownData: (data) \=\> set({ drillDownData: data }),  
  setLoading: (loading) \=\> set({ loading }),  
  setError: (error) \=\> set({ error }),  
  setCurrentYear: (year) \=\> set({ currentYear: year }),  
  setCurrentQuarter: (quarter) \=\> set({ currentQuarter: quarter }),  
  pushDrillDown: (target) \=\> set((state) \=\> ({   
    drillDownStack: \[...state.drillDownStack, target\]   
  })),  
  popDrillDown: () \=\> set((state) \=\> ({   
    drillDownStack: state.drillDownStack.slice(0, \-1)   
  })),  
  clearDrillDown: () \=\> set({ drillDownStack: \[\], drillDownData: null }),  
}));

### **7.5 Custom Hooks**

Copy  
// src/hooks/useDashboard.ts  
import { useEffect } from 'react';  
import { useDashboardStore } from '../store/dashboardStore';  
import { apiService } from '../services/api.service';

export const useDashboard \= () \=\> {  
  const {   
    dashboardData,   
    loading,   
    error,   
    currentYear,   
    currentQuarter,  
    setDashboardData,  
    setLoading,  
    setError  
  } \= useDashboardStore();

  const loadDashboard \= async (year?: number, quarter?: string) \=\> {  
    setLoading(true);  
    setError(null);  
      
    try {  
      const data \= await apiService.getDashboard(  
        year || currentYear,   
        quarter || currentQuarter || undefined  
      );  
      setDashboardData(data);  
    } catch (err: any) {  
      setError(err.message || 'Failed to load dashboard');  
    } finally {  
      setLoading(false);  
    }  
  };

  useEffect(() \=\> {  
    loadDashboard();  
  }, \[currentYear, currentQuarter\]);

  return { dashboardData, loading, error, loadDashboard };  
};

Copy  
// src/hooks/useDrillDown.ts  
import { useDashboardStore } from '../store/dashboardStore';  
import { apiService } from '../services/api.service';  
import { DrillDownRequest } from '../types/dashboard.types';

export const useDrillDown \= () \=\> {  
  const {  
    drillDownData,  
    drillDownStack,  
    setDrillDownData,  
    setLoading,  
    setError,  
    pushDrillDown,  
    popDrillDown,  
    clearDrillDown,  
  } \= useDashboardStore();

  const performDrillDown \= async (request: DrillDownRequest) \=\> {  
    setLoading(true);  
    setError(null);  
      
    try {  
      const data \= await apiService.drillDown(request);  
      setDrillDownData(data);  
      pushDrillDown(request.target);  
    } catch (err: any) {  
      setError(err.message || 'Failed to perform drill-down');  
    } finally {  
      setLoading(false);  
    }  
  };

  const goBack \= () \=\> {  
    popDrillDown();  
    if (drillDownStack.length \=== 1) {  
      clearDrillDown();  
    }  
  };

  return {   
    drillDownData,   
    drillDownStack,   
    performDrillDown,   
    goBack,   
    clearDrillDown   
  };  
};

### **7.6 Zone 1: Transformation Health (Spider Chart)**

Copy  
// src/components/Dashboard/Zone1Health.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsMore from 'highcharts/highcharts-more';  
import { Zone1Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsMore(Highcharts);

interface Zone1HealthProps {  
  data: Zone1Data;  
  year: number;  
}

export const Zone1Health: React.FC\<Zone1HealthProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleDimensionClick \= (dimensionName: string, score: number) \=\> {  
    performDrillDown({  
      zone: 'transformation\_health',  
      target: dimensionName,  
      context: {  
        dimension: dimensionName,  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      polar: true,  
      type: 'line',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: \`Transformation Health: ${data.overall\_health.toFixed(1)}%\`,  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    pane: {  
      size: '80%',  
    },  
      
    xAxis: {  
      categories: data.dimensions.map(d \=\> d.name),  
      tickmarkPlacement: 'on',  
      lineWidth: 0,  
      labels: {  
        style: { color: '\#a0a0b0', fontSize: '11px' },  
      },  
    },  
      
    yAxis: {  
      gridLineInterpolation: 'polygon',  
      lineWidth: 0,  
      min: 0,  
      max: 100,  
      labels: {  
        style: { color: '\#a0a0b0' },  
      },  
    },  
      
    tooltip: {  
      shared: true,  
      pointFormat: '\<span style="color:{series.color}"\>{series.name}: \<b\>{point.y:.1f}%\</b\>\<br/\>',  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
    },  
      
    legend: {  
      align: 'center',  
      verticalAlign: 'bottom',  
      itemStyle: { color: '\#a0a0b0' },  
    },  
      
    series: \[  
      {  
        name: 'Current',  
        type: 'area',  
        data: data.dimensions.map(d \=\> d.score),  
        pointPlacement: 'on',  
        color: '\#00AEEF',  
        fillOpacity: 0.3,  
        cursor: 'pointer',  
        point: {  
          events: {  
            click: function() {  
              const dimensionName \= data.dimensions\[this.index\].name;  
              const score \= this.y as number;  
              handleDimensionClick(dimensionName, score);  
            },  
          },  
        },  
      },  
      {  
        name: 'Target',  
        type: 'line',  
        data: data.dimensions.map(d \=\> d.target),  
        pointPlacement: 'on',  
        color: '\#28a745',  
        dashStyle: 'Dash',  
        marker: { enabled: false },  
      },  
    \],  
      
    plotOptions: {  
      series: {  
        animation: { duration: 1000 },  
      },  
    },  
  };

  return (  
    \<div className\="zone-1 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 1: Transformation Health\</h2\>  
        \<p className\="text-sm text-muted"\>Click any dimension to drill down\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
        
      {/\* Dimension Indicators \*/}  
      \<div className\="grid grid-cols-4 gap-3 mt-6"\>  
        {data.dimensions.map((dim, idx) \=\> (  
          \<div  
            key\={idx}  
            className\="p-3 bg-secondary rounded cursor-pointer hover:bg-opacity-80 transition"  
            onClick\={() \=\> handleDimensionClick(dim.name, dim.score)}  
          \>  
            \<div className\="flex items-center justify-between mb-1"\>  
              \<span className\="text-xs text-muted"\>{dim.name}\</span\>  
              \<span className\={\`text-xs ${  
                dim.trend \=== 'improving' ? 'text-success' :   
                dim.trend \=== 'declining' ? 'text-danger' : 'text-warning'  
              }\`}\>  
                {dim.trend \=== 'improving' ? '↑' : dim.trend \=== 'declining' ? '↓' : '→'}  
              \</span\>  
            \</div\>  
            \<div className\="text-lg font-bold text-primary"\>{dim.score.toFixed(1)}%\</div\>  
            \<div className\="text-xs text-muted"\>Target: {dim.target}%\</div\>  
          \</div\>  
        ))}  
      \</div\>  
    \</div\>  
  );  
};

### **7.7 Zone 2: Strategic Insights (Bubble Chart)**

Copy  
// src/components/Dashboard/Zone2Insights.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsMore from 'highcharts/highcharts-more';  
import { Zone2Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsMore(Highcharts);

interface Zone2InsightsProps {  
  data: Zone2Data;  
  year: number;  
}

export const Zone2Insights: React.FC\<Zone2InsightsProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleBubbleClick \= (bubble: any) \=\> {  
    performDrillDown({  
      zone: 'strategic\_insights',  
      target: bubble.name,  
      context: {  
        entity\_table: 'ent\_projects',  
        entity\_id: bubble.project\_id,  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      type: 'bubble',  
      plotBorderWidth: 1,  
      zoomType: 'xy',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: 'Strategic Insights: Objectives vs Projects',  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    xAxis: {  
      title: { text: 'Project Progress (%)', style: { color: '\#a0a0b0' } },  
      min: 0,  
      max: 100,  
      gridLineWidth: 1,  
      gridLineColor: '\#4a4a58',  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    yAxis: {  
      title: { text: 'Impact Score', style: { color: '\#a0a0b0' } },  
      min: 0,  
      max: 100,  
      gridLineColor: '\#4a4a58',  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    tooltip: {  
      useHTML: true,  
      headerFormat: '\<table\>',  
      pointFormat:   
        '\<tr\>\<th colspan="2"\>\<h3\>{point.name}\</h3\>\</th\>\</tr\>' \+  
        '\<tr\>\<th\>Progress:\</th\>\<td\>{point.x}%\</td\>\</tr\>' \+  
        '\<tr\>\<th\>Impact:\</th\>\<td\>{point.y}\</td\>\</tr\>' \+  
        '\<tr\>\<th\>Budget:\</th\>\<td\>${point.z}M\</td\>\</tr\>' \+  
        '\<tr\>\<td colspan="2"\>\<i\>Click for details\</i\>\</td\>\</tr\>',  
      footerFormat: '\</table\>',  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
      followPointer: true,  
    },  
      
    legend: { enabled: false },  
      
    plotOptions: {  
      bubble: {  
        minSize: 20,  
        maxSize: 80,  
        cursor: 'pointer',  
        dataLabels: {  
          enabled: false,  
        },  
        point: {  
          events: {  
            click: function() {  
              handleBubbleClick(this.options);  
            },  
          },  
        },  
      },  
    },  
      
    series: \[  
      {  
        type: 'bubble',  
        name: 'Projects',  
        data: data.bubbles.map(b \=\> ({  
          x: b.x,  
          y: b.y,  
          z: b.z,  
          name: b.name,  
          project\_id: b.project\_id,  
          objective\_id: b.objective\_id,  
        })),  
        color: '\#00AEEF',  
      },  
    \],  
  };

  return (  
    \<div className\="zone-2 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 2: Strategic Insights\</h2\>  
        \<p className\="text-sm text-muted"\>Bubble size \= Budget allocation\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
    \</div\>  
  );  
};

### **7.8 Zone 3: Internal Outputs (Bullet Charts)**

Copy  
// src/components/Dashboard/Zone3Outputs.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsBullet from 'highcharts/modules/bullet';  
import { Zone3Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsBullet(Highcharts);

interface Zone3OutputsProps {  
  data: Zone3Data;  
  year: number;  
}

export const Zone3Outputs: React.FC\<Zone3OutputsProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleMetricClick \= (entityType: string) \=\> {  
    const tableMap: Record\<string, string\> \= {  
      'Capabilities': 'ent\_capabilities',  
      'Processes': 'ent\_processes',  
      'IT Systems': 'ent\_it\_systems',  
    };

    performDrillDown({  
      zone: 'internal\_outputs',  
      target: entityType,  
      context: {  
        entity\_table: tableMap\[entityType\],  
        year: year,  
      },  
    });  
  };

  return (  
    \<div className\="zone-3 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 3: Internal Outputs\</h2\>  
        \<p className\="text-sm text-muted"\>Click any metric to drill down\</p\>  
      \</div\>  
        
      \<div className\="space-y-6"\>  
        {data.metrics.map((metric, idx) \=\> {  
          const chartOptions: Highcharts.Options \= {  
            chart: {  
              type: 'bullet',  
              inverted: true,  
              marginLeft: 150,  
              height: 100,  
              backgroundColor: 'transparent',  
            },  
              
            title: {  
              text: metric.entity\_type,  
              style: { color: '\#EBEBEB', fontSize: '14px' },  
            },  
              
            xAxis: {  
              categories: \[''\],  
              labels: { enabled: false },  
            },  
              
            yAxis: {  
              min: 0,  
              max: metric.target\_value \* 1.2,  
              plotBands: \[  
                { from: 0, to: metric.target\_value \* 0.6, color: 'rgba(220, 53, 69, 0.3)' },  
                { from: metric.target\_value \* 0.6, to: metric.target\_value \* 0.9, color: 'rgba(255, 193, 7, 0.3)' },  
                { from: metric.target\_value \* 0.9, to: metric.target\_value \* 1.2, color: 'rgba(40, 167, 69, 0.3)' },  
              \],  
              title: null,  
              labels: { style: { color: '\#a0a0b0' } },  
            },  
              
            legend: { enabled: false },  
              
            tooltip: {  
              backgroundColor: '\#2c2c38',  
              borderColor: '\#4a4a58',  
              style: { color: '\#EBEBEB' },  
              pointFormat: '\<b\>{point.y:.1f}\</b\> (Target: {series.options.targetOptions.y:.1f})',  
            },  
              
            plotOptions: {  
              series: {  
                cursor: 'pointer',  
                point: {  
                  events: {  
                    click: () \=\> handleMetricClick(metric.entity\_type),  
                  },  
                },  
              },  
            },  
              
            series: \[  
              {  
                type: 'bullet',  
                data: \[  
                  {  
                    y: metric.current\_value,  
                    target: metric.target\_value,  
                  },  
                \],  
                color: '\#00AEEF',  
                targetOptions: {  
                  width: '140%',  
                  height: 3,  
                  borderWidth: 0,  
                  color: '\#28a745',  
                  y: metric.target\_value,  
                },  
              },  
            \],  
          };

          return (  
            \<div key\={idx} className\="cursor-pointer hover:opacity-80 transition"\>  
              \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
              \<div className\="flex justify-between text-xs text-muted mt-1"\>  
                \<span\>Current: {metric.current\_value.toFixed(1)}\</span\>  
                \<span\>Performance: {metric.performance\_percentage.toFixed(1)}%\</span\>  
                \<span\>Target: {metric.target\_value.toFixed(1)}\</span\>  
              \</div\>  
            \</div\>  
          );  
        })}  
      \</div\>  
    \</div\>  
  );  
};

### **7.9 Zone 4: Sector Outcomes (Combo Chart)**

Copy  
// src/components/Dashboard/Zone4Outcomes.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import { Zone4Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

interface Zone4OutcomesProps {  
  data: Zone4Data;  
  year: number;  
}

export const Zone4Outcomes: React.FC\<Zone4OutcomesProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleSectorClick \= (sector: string) \=\> {  
    const tableMap: Record\<string, string\> \= {  
      'Citizens': 'sec\_citizens',  
      'Businesses': 'sec\_businesses',  
      'Transactions': 'sec\_data\_transactions',  
    };

    performDrillDown({  
      zone: 'sector\_outcomes',  
      target: sector,  
      context: {  
        entity\_table: tableMap\[sector\],  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      type: 'column',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: 'Sector-Level Outcomes',  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    xAxis: {  
      categories: data.outcomes.map(o \=\> o.sector),  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    yAxis: {  
      min: 0,  
      max: 100,  
      title: { text: 'Score', style: { color: '\#a0a0b0' } },  
      labels: { style: { color: '\#a0a0b0' } },  
      gridLineColor: '\#4a4a58',  
    },  
      
    tooltip: {  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
      shared: true,  
    },  
      
    legend: {  
      itemStyle: { color: '\#a0a0b0' },  
    },  
      
    plotOptions: {  
      column: {  
        cursor: 'pointer',  
        point: {  
          events: {  
            click: function() {  
              handleSectorClick(this.category as string);  
            },  
          },  
        },  
      },  
      line: {  
        marker: { enabled: false },  
      },  
    },  
      
    series: \[  
      {  
        type: 'column',  
        name: 'Current Value',  
        data: data.outcomes.map(o \=\> o.value),  
        color: '\#00AEEF',  
      },  
      {  
        type: 'line',  
        name: 'Target',  
        data: data.outcomes.map(o \=\> o.target),  
        color: '\#28a745',  
        dashStyle: 'Dash',  
      },  
    \],  
  };

  return (  
    \<div className\="zone-4 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 4: Sector Outcomes\</h2\>  
        \<p className\="text-sm text-muted"\>Click any sector to drill down\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
        
      {/\* Trend Sparklines \*/}  
      \<div className\="grid grid-cols-3 gap-4 mt-6"\>  
        {data.outcomes.map((outcome, idx) \=\> (  
          \<div  
            key\={idx}  
            className\="p-3 bg-secondary rounded cursor-pointer hover:bg-opacity-80 transition"  
            onClick\={() \=\> handleSectorClick(outcome.sector)}  
          \>  
            \<div className\="text-sm text-muted mb-1"\>{outcome.sector}\</div\>  
            \<div className\="text-xl font-bold text-primary"\>{outcome.value.toFixed(1)}%\</div\>  
            \<div className\="text-xs text-muted"\>Target: {outcome.target}%\</div\>  
            {/\* Simple sparkline visualization \*/}  
            \<div className\="mt-2 flex items-end space-x-1" style\={{ height: '30px' }}\>  
              {outcome.trend.map((val, i) \=\> (  
                \<div  
                  key\={i}  
                  className\="flex-1 bg-accent rounded-t"  
                  style\={{ height: \`${(val / 100) \* 100}%\` }}  
                /\>  
              ))}  
            \</div\>  
          \</div\>  
        ))}  
      \</div\>  
    \</div\>  
  );  
};

### **7.10 Main Dashboard Container**

Copy  
// src/components/Dashboard/Dashboard.tsx  
import React, { useEffect } from 'react';  
import { useDashboard } from '../../hooks/useDashboard';  
import { useDashboardStore } from '../../store/dashboardStore';  
import { Zone1Health } from './Zone1Health';  
import { Zone2Insights } from './Zone2Insights';  
import { Zone3Outputs } from './Zone3Outputs';  
import { Zone4Outcomes } from './Zone4Outcomes';  
import { LoadingState } from './LoadingState';

export const Dashboard: React.FC \= () \=\> {  
  const { dashboardData, loading, error, loadDashboard } \= useDashboard();  
  const { currentYear, currentQuarter, setCurrentYear, setCurrentQuarter } \= useDashboardStore();

  if (loading) {  
    return \<LoadingState /\>;  
  }

  if (error) {  
    return (  
      \<div className\="flex items-center justify-center min-h-screen bg-primary"\>  
        \<div className\="text-center"\>  
          \<div className\="text-danger text-xl mb-4"\>⚠️ Error Loading Dashboard\</div\>  
          \<div className\="text-muted"\>{error}\</div\>  
          \<button  
            onClick\={() \=\> loadDashboard()}  
            className="mt-4 px-6 py-2 bg-accent text-white rounded hover:bg-opacity-80 transition"  
          \>  
            Retry  
          \</button\>  
        \</div\>  
      \</div\>  
    );  
  }

  if (\!dashboardData) {  
    return null;  
  }

  return (  
    \<div className\="min-h-screen bg-primary p-6"\>  
      {/\* Header \*/}  
      \<div className\="mb-6 flex items-center justify-between"\>  
        \<div\>  
          \<h1 className\="text-3xl font-bold text-primary"\>Transformation Analytics Dashboard\</h1\>  
          \<p className\="text-muted"\>  
            Holistic view of transformation program health and performance  
          \</p\>  
        \</div\>  
          
        {/\* Year/Quarter Selector \*/}  
        \<div className\="flex space-x-4"\>  
          \<select  
            value\={currentYear}  
            onChange\={(e) \=\> setCurrentYear(Number(e.target.value))}  
            className="px-4 py-2 bg-panel border border-border rounded text-primary"  
          \>  
            {\[2024, 2023, 2022, 2021\].map(year \=\> (  
              \<option key\={year} value\={year}\>{year}\</option\>  
            ))}  
          \</select\>  
            
          \<select  
            value\={currentQuarter || ''}  
            onChange\={(e) \=\> setCurrentQuarter(e.target.value || null)}  
            className="px-4 py-2 bg-panel border border-border rounded text-primary"  
          \>  
            \<option value\=""\>All Quarters\</option\>  
            \<option value\="Q1"\>Q1\</option\>  
            \<option value\="Q2"\>Q2\</option\>  
            \<option value\="Q3"\>Q3\</option\>  
            \<option value\="Q4"\>Q4\</option\>  
          \</select\>  
        \</div\>  
      \</div\>  
        
      {/\* 4-Zone Grid Layout \*/}  
      \<div className\="grid grid-cols-2 gap-6"\>  
        \<Zone1Health data\={dashboardData.zone1} year\={currentYear} /\>  
        \<Zone2Insights data\={dashboardData.zone2} year\={currentYear} /\>  
        \<Zone3Outputs data\={dashboardData.zone3} year\={currentYear} /\>  
        \<Zone4Outcomes data\={dashboardData.zone4} year\={currentYear} /\>  
      \</div\>  
        
      {/\* Cache Indicator \*/}  
      {dashboardData.cache\_hit && (  
        \<div className\="mt-4 text-xs text-muted text-center"\>  
          ⚡ Data loaded from cache (generated at {new Date(dashboardData.generated\_at).toLocaleString()})  
        \</div\>  
      )}  
    \</div\>  
  );  
};

---



---

**DOCUMENT STATUS:** ✅ COMPLETE - Extracted from existing comprehensive spec
