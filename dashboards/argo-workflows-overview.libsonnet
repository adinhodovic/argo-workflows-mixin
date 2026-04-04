local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local variable = dashboard.variable;
local query = variable.query;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'argo-workflows-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);
      local workflowNamespaceSelector = 'exported_namespace=~"$workflow_namespace"';
      local workflowNamespaceVariable =
        query.new(
          'workflow_namespace',
          'label_values(argo_workflows_total_count{%(cluster)s}, exported_namespace)' % util.filters($._config)
        ) +
        query.withDatasourceFromVariable(defaultVariables.datasource) +
        query.withSort() +
        query.generalOptions.withLabel('Workflow Namespace') +
        query.selectionOptions.withMulti(true) +
        query.selectionOptions.withIncludeAll(true) +
        query.refresh.onLoad() +
        query.refresh.onTime();
      local workflowJobVariable =
        query.new(
          'job',
          'label_values(argo_workflows_total_count{%(cluster)s, %(namespace)s}, job)' % {
            cluster: util.filters($._config).cluster,
            namespace: util.filters($._config).namespace,
          }
        ) +
        query.withDatasourceFromVariable(defaultVariables.datasource) +
        query.withSort() +
        query.generalOptions.withLabel('Job') +
        query.selectionOptions.withMulti(true) +
        query.selectionOptions.withIncludeAll(true) +
        query.refresh.onLoad() +
        query.refresh.onTime();

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        workflowJobVariable,
        workflowNamespaceVariable,
      ];

      local defaultFilters = util.filters($._config);
      local workflowBaseFilters = defaultFilters {
        workflowNamespace: workflowNamespaceSelector,
        base: |||
          %(cluster)s,
          %(namespace)s,
          %(workflowNamespace)s,
          %(job)s
        ||| % {
          cluster: defaultFilters.cluster,
          namespace: defaultFilters.namespace,
          workflowNamespace: workflowNamespaceSelector,
          job: defaultFilters.job,
        },
      };
      local workflowFilters = workflowBaseFilters {
        default: workflowBaseFilters.base,
      };
      local queries = {
        // Summary
        activeWorkflows: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase=~"Pending|Running"
            }
          )
        ||| % defaultFilters,

        unhealthyWorkflows: |||
          sum(
            argo_workflows_gauge{
              %(default)s,
              phase=~"Error|Failed"
            }
          )
        ||| % defaultFilters,

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
        ||| % workflowFilters,

        succeededWorkflows1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[1h]
            )
          )
        ||| % workflowFilters,

        errorWorkflows1h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Error"
              }[1h]
            )
          )
        ||| % workflowFilters,

        workflowCompletions6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase=~"Succeeded|Failed|Error"
              }[6h]
            )
          )
        ||| % workflowFilters,

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

        workflowCompletionsByPhase6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s
              }[6h]
            )
          ) by (phase)
        ||| % workflowFilters,

        workflowCompletionsByNamespace6h: |||
          topk(20,
            sum(
              increase(
                argo_workflows_total_count{
                  %(default)s
                }[6h]
              )
            ) by (exported_namespace)
          )
        ||| % workflowFilters,

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

        workflowCompletionsByPhase: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (phase)
        ||| % workflowFilters,

        workflowSuccessRate6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[6h]
            )
          )
          /
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s
              }[6h]
            )
          )
          * 100
        ||| % workflowFilters,

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

        podPendingByReason: |||
          sum(
            increase(
              argo_workflows_pod_pending_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (reason)
        ||| % defaultFilters,

        podRestartsByReason: |||
          sum(
            increase(
              argo_workflows_pod_restarts_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (reason)
        ||| % defaultFilters,

        podMissing: |||
          sum(
            increase(
              argo_workflows_pod_missing{
                %(default)s
              }[$__rate_interval]
            )
          ) by (node_phase, recently_started)
        ||| % defaultFilters,

        cronWorkflowTriggered: |||
          sum(
            increase(
              argo_workflows_cronworkflows_triggered_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (name, namespace)
        ||| % defaultFilters,

        cronWorkflowConcurrencyPolicyTriggered: |||
          sum(
            increase(
              argo_workflows_cronworkflows_concurrencypolicy_triggered{
                %(default)s
              }[$__rate_interval]
            )
          ) by (name, namespace)
        ||| % defaultFilters,

        // Table
        workflowCompletionsByNamespace6hForTable: |||
          topk(40,
            sum(
              increase(
                argo_workflows_total_count{
                  %(default)s
                }[6h]
              )
            ) by (exported_namespace)
          )
        ||| % workflowFilters,

        local namespaceRpsTop40k = {
          rpsTop40k: |||
            and on (exported_namespace) (
              %s
            )
          ||| % queries.workflowCompletionsByNamespace6hForTable,
        },

        succeededWorkflowsByNamespace6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Succeeded"
              }[6h]
            )
          ) by (exported_namespace)
          %(rpsTop40k)s
        ||| % (workflowFilters + namespaceRpsTop40k),

        failedWorkflowsByNamespace6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Failed"
              }[6h]
            )
          ) by (exported_namespace)
          %(rpsTop40k)s
        ||| % (workflowFilters + namespaceRpsTop40k),

        errorWorkflowsByNamespace6h: |||
          sum(
            increase(
              argo_workflows_total_count{
                %(default)s,
                phase="Error"
              }[6h]
            )
          ) by (exported_namespace)
          %(rpsTop40k)s
        ||| % (workflowFilters + namespaceRpsTop40k),
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

        activeWorkflowsStat:
          mixinUtils.dashboards.statPanel(
            'Active Workflows',
            'short',
            queries.activeWorkflows,
            description='Number of workflows currently in Pending or Running. This is the main at-a-glance workload indicator for the cluster.',
          ),

        unhealthyWorkflowsStat:
          mixinUtils.dashboards.statPanel(
            'Unhealthy Workflows',
            'short',
            queries.unhealthyWorkflows,
            description='Number of workflows currently in Failed or Error. Any sustained non-zero value deserves investigation.',
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

        workflowCompletions1hStat:
          mixinUtils.dashboards.statPanel(
            'Workflow Completions [6h]',
            'short',
            queries.workflowCompletions6h,
            instant=true,
            description='Number of workflows that reached a terminal phase in the past 6 hours. Use this to gauge recent throughput.',
          ),

        workflowSuccessRateStat:
          mixinUtils.dashboards.statPanel(
            'Success Rate [6h]',
            'percent',
            queries.workflowSuccessRate6h,
            instant=true,
            description='Percentage of completed workflows succeeding over the past 6 hours. No data means no completed workflows in that window.',
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

        workflowCompletionsByPhase6hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Workflow Completions by Phase [6h]',
            'short',
            queries.workflowCompletionsByPhase6h,
            '{{ phase }}',
            description='Distribution of workflow completions by phase over the past 6 hours. High proportions of Failed or Error phases indicate systemic issues.',
          ),

        workflowCompletionsByNamespace6hPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Workflow Completions by Namespace [6h]',
            'short',
            queries.workflowCompletionsByNamespace6h,
            '{{ exported_namespace }}',
            description='Distribution of workflow activity across namespaces over the past 6 hours. Identifies which namespaces are the most active.',
          ),

        unhealthyWorkflowsByNamespacePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Failed/Error Workflows by Namespace [6h]',
            'short',
            [
              {
                expr: |||
                  topk(10,
                    sum(
                      increase(
                        argo_workflows_total_count{
                          %(default)s,
                          phase=~"Error|Failed"
                        }[6h]
                      )
                    ) by (exported_namespace)
                  )
                ||| % workflowFilters,
                legend: '{{ exported_namespace }}',
              },
            ],
            description='Namespaces with the most Failed or Error workflow completions over the past 6 hours. This highlights problem areas without drilling into the table first.',
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

        workflowCompletionsByPhaseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Completions by Phase',
            'short',
            queries.workflowCompletionsByPhase,
            '{{ phase }}',
            description='Workflows reaching each phase within each interval. This shows throughput and where recent workflow outcomes are landing.',
            stack='normal',
          ),

        workflowSuccessRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Workflow Success Rate [6h]',
            'percent',
            [
              {
                expr: queries.workflowSuccessRate6h,
                legend: 'Success Rate [6h]',
              },
            ],
            description='Percentage of workflows completing successfully over the past 6 hours. Drops below expected levels indicate workflow logic errors, infrastructure issues, or resource constraints.',
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

        podPendingByReasonTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pending Pods by Reason',
            'short',
            queries.podPendingByReason,
            '{{ reason }}',
            description='Pods entering pending state within each interval, grouped by reason. Helps identify scheduling or resource issues behind pod backlog.',
            stack='normal',
          ),

        podRestartsByReasonTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Pod Restarts by Reason',
            'short',
            queries.podRestartsByReason,
            '{{ reason }}',
            description='Pod restarts within each interval, grouped by reason. Persistent restarts indicate infrastructure instability.',
            stack='normal',
          ),

        podMissingTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Missing Pods',
            'short',
            queries.podMissing,
            '{{ node_phase }}/{{ recently_started }}',
            description='Pods reported missing within each interval. Spikes may indicate aggressive eviction, node failure, or resource pressure.',
            stack='normal',
          ),

        cronWorkflowTriggersTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'CronWorkflow Triggers',
            'short',
            queries.cronWorkflowTriggered,
            '{{ namespace }}/{{ name }}',
            description='CronWorkflow triggers within each interval. Use this to verify scheduled workflows are firing as expected.',
            stack='normal',
          ),

        cronWorkflowConcurrencyPolicyTriggeredTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'CronWorkflow Concurrency Policy Triggered',
            'short',
            queries.cronWorkflowConcurrencyPolicyTriggered,
            '{{ namespace }}/{{ name }}',
            description='CronWorkflow concurrency policy actions within each interval. Use this to spot schedules being affected by `Forbid` or `Replace` policy behavior.',
            stack='normal',
          ),

        // Table
        workflowOverviewTable:
          mixinUtils.dashboards.tablePanel(
            'Workflow Overview by Namespace [6h]',
            'short',
            [
              {
                expr: queries.workflowCompletionsByNamespace6hForTable,
                legend: 'Total Workflows',
              },
              {
                expr: queries.succeededWorkflowsByNamespace6h,
                legend: 'Succeeded',
              },
              {
                expr: queries.failedWorkflowsByNamespace6h,
                legend: 'Failed',
              },
              {
                expr: queries.errorWorkflowsByNamespace6h,
                legend: 'Errors',
              },
              {
                expr: |||
                  (
                    %(succeeded)s
                    /
                    %(total)s
                  ) * 100
                ||| % {
                  succeeded: queries.succeededWorkflowsByNamespace6h,
                  total: queries.workflowCompletionsByNamespace6hForTable,
                },
                legend: 'Success Rate',
              },
            ],
            description='Workflow completions by workflow namespace over the past 6 hours, including succeeded, failed, error, and derived success rate.',
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
                    exported_namespace: 'Namespace',
                    'Value #A': 'Total Workflows',
                    'Value #B': 'Succeeded',
                    'Value #C': 'Failed',
                    'Value #D': 'Errors',
                    'Value #E': 'Success Rate',
                  },
                  indexByName: {
                    exported_namespace: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                    'Value #D': 4,
                    'Value #E': 5,
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
                tbStandardOptions.withUnit('short') +
                tbStandardOptions.withDecimals(0)
              ),
              tbOverride.byName.new('Succeeded') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('short') +
                tbStandardOptions.withDecimals(0)
              ),
              tbOverride.byName.new('Failed') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('short') +
                tbStandardOptions.withDecimals(0)
              ),
              tbOverride.byName.new('Errors') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('short') +
                tbStandardOptions.withDecimals(0)
              ),
              tbOverride.byName.new('Success Rate') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent') +
                tbStandardOptions.withDecimals(1)
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
            panels.activeWorkflowsStat,
            panels.unhealthyWorkflowsStat,
            panels.workflowCompletions1hStat,
            panels.workflowSuccessRateStat,
            panels.runningPodsStat,
            panels.pendingWorkflowsStat,
          ],
          panelWidth=4,
          panelHeight=4,
          startY=1
        ) +
        grid.wrapPanels(
          [
            panels.workflowsByPhasePieChart,
            panels.workflowCompletionsByPhase6hPieChart,
            panels.unhealthyWorkflowsByNamespacePieChart,
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
            panels.workflowOverviewTable +
            tablePanel.gridPos.withW(24) +
            tablePanel.gridPos.withH(10),
            panels.workflowGaugeByPhaseTimeSeries,
            panels.workflowCompletionsByPhaseTimeSeries,
            panels.workflowSuccessRateTimeSeries,
            panels.operationDurationTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=12
        ) +
        [
          row.new('Pods') +
          row.gridPos.withX(0) +
          row.gridPos.withY(44) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.podsGaugeByPhaseTimeSeries,
            panels.podPendingByReasonTimeSeries,
            panels.podRestartsByReasonTimeSeries,
            panels.podMissingTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=45
        ) +
        [
          row.new('CronWorkflows') +
          row.gridPos.withX(0) +
          row.gridPos.withY(61) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.cronWorkflowTriggersTimeSeries,
            panels.cronWorkflowConcurrencyPolicyTriggeredTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=62
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
