local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'argo-workflows-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        // Summary
        runningWorkflows: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase="Running"
            }
          )
        ||| % defaultFilters,

        pendingWorkflows: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase="Pending"
            }
          )
        ||| % defaultFilters,

        failedWorkflows1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Failed"
              }[1h]
            )
          )
        ||| % defaultFilters,

        succeededWorkflows1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[1h]
            )
          )
        ||| % defaultFilters,

        errorWorkflows1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Error"
              }[1h]
            )
          )
        ||| % defaultFilters,

        runningPods: |||
          sum(
            argo_workflows_pods_gauge{
              %(default)s,
              phase="Running"
            }
          )
        ||| % defaultFilters,

        pendingPods: |||
          sum(
            argo_workflows_pods_gauge{
              %(default)s,
              phase="Pending"
            }
          )
        ||| % defaultFilters,

        isLeader: |||
          max(
            argo_workflows_is_leader{
              %(default)s
            }
          )
        ||| % defaultFilters,

        workflowsByPhasePieChart: |||
          sum(
            argo_workflows_gauge{
              %(default)s
            }
          ) by (phase)
        ||| % defaultFilters,

        workflowRateByPhase1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s
              }[1h]
            )
          ) by (phase)
        ||| % defaultFilters,

        workflowRateByNamespace1h: |||
          topk(20,
            sum(
              increase(
                argo_workflows_total_count{
                  %(default)s
                }[1h]
              )
            ) by (namespace)
          )
        ||| % defaultFilters,

        podsByPhasePieChart: |||
          sum(
            argo_workflows_pods_gauge{
              %(default)s
            }
          ) by (phase)
        ||| % defaultFilters,

        // Workflows
        workflowGaugeByPhase: |||
          sum(
            argo_workflows_gauge{
              %(default)s
            }
          ) by (phase)
        ||| % defaultFilters,

        workflowRateByPhase: |||
          sum(
            rate(
              argo_workflows_total_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (phase)
        ||| % defaultFilters,

        workflowSuccessRate: |||
          sum(
            rate(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              argo_workflows_total_count{
                %(default)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,

        workflowFailureRate: |||
          sum(
            rate(
              argo_workflows_total_count{
                %(default)s,
                phase=~"Failed|Error"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              argo_workflows_total_count{
                %(default)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,

        operationDurationP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_operation_duration_seconds_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % defaultFilters,
        operationDurationP95: std.strReplace(queries.operationDurationP50, '0.5', '0.95'),
        operationDurationP99: std.strReplace(queries.operationDurationP50, '0.5', '0.99'),

        // Pods
        podsGaugeByPhase: |||
          sum(
            argo_workflows_pods_gauge{
              %(default)s
            }
          ) by (phase)
        ||| % defaultFilters,

        podRateByPhase: |||
          sum(
            rate(
              argo_workflows_pods_total_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (phase)
        ||| % defaultFilters,

        podPendingByReason: |||
          sum(
            rate(
              argo_workflows_pod_pending_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (reason)
        ||| % defaultFilters,

        podRestartsByReason: |||
          sum(
            rate(
              argo_workflows_pod_restarts_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (reason)
        ||| % defaultFilters,

        podMissing: |||
          sum(
            rate(
              argo_workflows_pod_missing{
                %(default)s
              }[$__rate_interval]
            )
          ) by (node_phase, recently_started)
        ||| % defaultFilters,

        // Table
        workflowRateByNamespace1hForTable: |||
          topk(40,
            sum(
              increase(
                argo_workflows_total_count{
                  %(default)s
                }[1h]
              )
            ) by (namespace)
          )
        ||| % defaultFilters,

        local namespaceRpsTop40k = {
          rpsTop40k: |||
            and on (namespace) (
              %s
            )
          ||| % queries.workflowRateByNamespace1hForTable,
        },

        succeededWorkflowsByNamespace1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[1h]
            )
          ) by (namespace)
          %(rpsTop40k)s
        ||| % (defaultFilters + namespaceRpsTop40k),

        failedWorkflowsByNamespace1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Failed"
              }[1h]
            )
          ) by (namespace)
          %(rpsTop40k)s
        ||| % (defaultFilters + namespaceRpsTop40k),

        errorWorkflowsByNamespace1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Error"
              }[1h]
            )
          ) by (namespace)
          %(rpsTop40k)s
        ||| % (defaultFilters + namespaceRpsTop40k),

        pendingWorkflowsByNamespace: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase="Pending"
            }
          ) by (namespace)
          %(rpsTop40k)s
        ||| % (defaultFilters + namespaceRpsTop40k),

        runningWorkflowsByNamespace: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase="Running"
            }
          ) by (namespace)
          %(rpsTop40k)s
        ||| % (defaultFilters + namespaceRpsTop40k),
      };

      local panels = {

        // Summary
        runningWorkflowsStat:
          mixinUtils.dashboards.statPanel(
            'Running Workflows',
            'short',
            queries.runningWorkflows,
            description='Number of workflows currently in the Running phase. Sudden drops may indicate controller issues or resource constraints.',
          ),

        pendingWorkflowsStat:
          mixinUtils.dashboards.statPanel(
            'Pending Workflows',
            'short',
            queries.pendingWorkflows,
            description='Number of workflows currently in the Pending phase. A high count may indicate resource constraints, scheduling issues, or parallelism limits.',
          ),

        failedWorkflows1hStat:
          mixinUtils.dashboards.statPanel(
            'Failed Workflows [1h]',
            'short',
            queries.failedWorkflows1h,
            description='Number of workflows that entered the Failed phase in the past hour. Non-zero values require investigation.',
          ),

        succeededWorkflows1hStat:
          mixinUtils.dashboards.statPanel(
            'Succeeded Workflows [1h]',
            'short',
            queries.succeededWorkflows1h,
            description='Number of workflows that completed successfully in the past hour.',
          ),

        runningPodsStat:
          mixinUtils.dashboards.statPanel(
            'Running Pods',
            'short',
            queries.runningPods,
            description='Number of workflow-created pods currently running. Compare with running workflows to assess parallelism.',
          ),

        isLeaderStat:
          mixinUtils.dashboards.statPanel(
            'Controller Is Leader',
            'short',
            queries.isLeader,
            description='Whether the controller is the current leader. A value of 0 indicates no active leader which means workflows will not be processed.',
          ),

        workflowsByPhasePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Current Workflows by Phase',
            'short',
            queries.workflowsByPhasePieChart,
            '{{ phase }}',
            description='Distribution of currently active workflows across phases (Pending, Running, Succeeded, Failed, Error). A healthy system shows mostly Running and Succeeded workflows.',
          ),

        workflowRateByPhase1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Workflow Completions by Phase [1h]',
            'short',
            queries.workflowRateByPhase1h,
            '{{ phase }}',
            description='Distribution of workflow completions by phase over the past hour. High proportions of Failed or Error phases indicate systemic issues.',
          ),

        workflowRateByNamespace1hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Workflow Completions by Namespace [1h]',
            'short',
            queries.workflowRateByNamespace1h,
            '{{ namespace }}',
            description='Distribution of workflow activity across namespaces over the past hour. Identifies which namespaces are the most active.',
          ),

        podsByPhasePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Current Pods by Phase',
            'short',
            queries.podsByPhasePieChart,
            '{{ phase }}',
            description='Distribution of workflow-created pods across phases. High Pending counts may indicate scheduling issues or resource constraints.',
          ),

        // Workflows
        workflowGaugeByPhaseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Current Workflows by Phase',
            'short',
            queries.workflowGaugeByPhase,
            '{{ phase }}',
            description='Number of workflows in each phase over time. Rising Pending counts indicate bottlenecks. Spikes in Running may indicate batch submissions.',
            stack='normal',
          ),

        workflowRateByPhaseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Rate by Phase',
            'ops',
            queries.workflowRateByPhase,
            '{{ phase }}',
            description='Rate of workflows entering each phase over time. Use this to identify trends in workflow failures, errors, and throughput.',
            stack='normal',
          ),

        workflowSuccessRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Success Rate',
            'percent',
            [
              {
                expr: queries.workflowSuccessRate,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of workflows completing successfully. Drops below expected levels indicate workflow logic errors, infrastructure issues, or resource constraints.',
            min=0,
            max=100,
          ),

        workflowFailureRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Failure Rate',
            'percent',
            [
              {
                expr: queries.workflowFailureRate,
                legend: 'Failure Rate',
              },
            ],
            description='Percentage of workflows failing or erroring. Rising failure rates require investigation into workflow logs and node status.',
            min=0,
            max=100,
          ),

        operationDurationTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Operation Duration',
            's',
            [
              {
                expr: queries.operationDurationP50,
                legend: 'P50',
              },
              {
                expr: queries.operationDurationP95,
                legend: 'P95',
              },
              {
                expr: queries.operationDurationP99,
                legend: 'P99',
              },
            ],
            description='Duration of workflow reconciliation operations. Rising latency indicates controller overload, API server slowness, or complex workflow processing. P99 spikes precede visible degradation.',
          ),

        // Pods
        podsGaugeByPhaseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Current Pods by Phase',
            'short',
            queries.podsGaugeByPhase,
            '{{ phase }}',
            description='Number of workflow-created pods in each phase over time. Rising Pending pods indicate scheduling issues or resource constraints.',
            stack='normal',
          ),

        podRateByPhaseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pod Rate by Phase',
            'ops',
            queries.podRateByPhase,
            '{{ phase }}',
            description='Rate of pods entering each phase. Use to monitor pod throughput and identify scheduling bottlenecks.',
            stack='normal',
          ),

        podPendingByReasonTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pod Pending Rate by Reason',
            'ops',
            queries.podPendingByReason,
            '{{ reason }}',
            description='Rate of pods entering pending state by reason. Helps identify specific scheduling or resource issues causing pod delays.',
            stack='normal',
          ),

        podRestartsByReasonTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pod Restarts by Reason',
            'ops',
            queries.podRestartsByReason,
            '{{ reason }}',
            description='Rate of pod restarts due to infrastructure failures. Common reasons include Evicted, NodeShutdown, and NodeAffinity. Persistent restarts indicate infrastructure instability.',
            stack='normal',
          ),

        podMissingTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Missing Pods',
            'ops',
            queries.podMissing,
            '{{ node_phase }}/{{ recently_started }}',
            description='Rate of pods not found or deleted by Kubernetes. May indicate aggressive pod eviction, node failures, or resource pressure.',
            stack='normal',
          ),

        // Table
        workflowOverviewTable:
          mixinUtils.dashboards.tablePanel(
            'Workflow Overview by Namespace [1h]',
            'short',
            [
              {
                expr: queries.workflowRateByNamespace1hForTable,
                legend: 'Total Workflows',
              },
              {
                expr: queries.succeededWorkflowsByNamespace1h,
                legend: 'Succeeded',
              },
              {
                expr: queries.failedWorkflowsByNamespace1h,
                legend: 'Failed',
              },
              {
                expr: queries.errorWorkflowsByNamespace1h,
                legend: 'Errors',
              },
              {
                expr: queries.runningWorkflowsByNamespace,
                legend: 'Running',
              },
              {
                expr: queries.pendingWorkflowsByNamespace,
                legend: 'Pending',
              },
            ],
            description='An overview table showing workflow counts by namespace over the past hour.',
            sortBy={ name: 'Total Workflows', desc: true },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    namespace: 'Namespace',
                    'Value #A': 'Total Workflows',
                    'Value #B': 'Succeeded',
                    'Value #C': 'Failed',
                    'Value #D': 'Errors',
                    'Value #E': 'Running',
                    'Value #F': 'Pending',
                  },
                  indexByName: {
                    namespace: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                    'Value #D': 4,
                    'Value #E': 5,
                    'Value #F': 6,
                  },
                  excludeByName: {
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('Total Workflows') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('short')
              ),
            ]
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.runningWorkflowsStat,
            panels.pendingWorkflowsStat,
            panels.failedWorkflows1hStat,
            panels.succeededWorkflows1hStat,
            panels.runningPodsStat,
            panels.isLeaderStat,
          ],
          panelWidth=4,
          panelHeight=4,
          startY=1
        ) +
        grid.wrapPanels(
          [
            panels.workflowsByPhasePieChart,
            panels.workflowRateByPhase1hPieChart,
            panels.workflowRateByNamespace1hPieChart,
            panels.podsByPhasePieChart,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=5
        ) +
        [
          row.new('Workflows') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.workflowGaugeByPhaseTimeSeries,
            panels.workflowRateByPhaseTimeSeries,
            panels.workflowSuccessRateTimeSeries,
            panels.workflowFailureRateTimeSeries,
            panels.operationDurationTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=12
        ) +
        grid.wrapPanels(
          [
            panels.workflowOverviewTable,
          ],
          panelWidth=24,
          panelHeight=12,
          startY=36
        ) +
        [
          row.new('Pods') +
          row.gridPos.withX(0) +
          row.gridPos.withY(48) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.podsGaugeByPhaseTimeSeries,
            panels.podRateByPhaseTimeSeries,
            panels.podPendingByReasonTimeSeries,
            panels.podRestartsByReasonTimeSeries,
            panels.podMissingTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=49
        );


      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Argo Workflows / Overview',
      ) +
      dashboard.withDescription('A comprehensive overview dashboard for monitoring Argo Workflows deployments. Provides high-level metrics across all workflows and pods including current phase counts, completion rates, success/failure rates, operation durations, and pod lifecycle metrics. Use this dashboard to identify trends, spot anomalies, and drill down into specific namespaces. %s' % mixinUtils.dashboards.dashboardDescriptionLink('argo-workflows-mixin', 'https://github.com/adinhodovic/argo-workflows-mixin')) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('Argo Workflows', $._config, dropdown=true)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
