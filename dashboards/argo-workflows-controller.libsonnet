local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  local dashboardName = 'argo-workflows-controller',
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
      local controllerFilters = defaultFilters;
      local queries = {
        // Summary
        controllerIsLeader: |||
          max(
            argo_workflows_is_leader{
              %(default)s
            }
          )
        ||| % controllerFilters,

        controllerErrorRate: |||
          sum(
            rate(
              argo_workflows_error_count{
                %(default)s
              }[$__rate_interval]
            )
          )
        ||| % controllerFilters,

        k8sNonSuccessRequestRate: |||
          sum(
            rate(
              argo_workflows_k8s_request_total{
                %(default)s,
                status_code!~"2..|101"
              }[$__rate_interval]
            )
          )
        ||| % controllerFilters,

        totalQueueDepth: |||
          sum(
            argo_workflows_queue_depth_gauge{
              %(default)s
            }
          )
        ||| % controllerFilters,

        totalBusyWorkers: |||
          sum(
            argo_workflows_workers_busy_count{
              %(default)s
            }
          )
        ||| % controllerFilters,

        // Errors
        errorCountByCause: |||
          sum(
            rate(
              argo_workflows_error_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (cause)
        ||| % controllerFilters,

        logMessagesByLevel: |||
          sum(
            rate(
              argo_workflows_log_messages{
                %(default)s
              }[$__rate_interval]
            )
          ) by (level)
        ||| % controllerFilters,

        // K8s API
        k8sRequestRateByKindVerb: |||
          sum(
            rate(
              argo_workflows_k8s_request_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (kind, verb)
        ||| % controllerFilters,

        k8sRequestRateByStatusCode: |||
          sum(
            rate(
              argo_workflows_k8s_request_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (status_code)
        ||| % controllerFilters,

        k8sRequestSuccessRate: |||
          (
            sum(
              rate(
                argo_workflows_k8s_request_total{
                  %(default)s,
                  status_code=~"2..|101"
                }[$__rate_interval]
              )
            )
            /
            sum(
              rate(
                argo_workflows_k8s_request_total{
                  %(default)s
                }[$__rate_interval]
              )
            )
          ) * 100
        ||| % controllerFilters,

        k8sRequestDurationP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_k8s_request_duration_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % controllerFilters,
        k8sRequestDurationP95: std.strReplace(queries.k8sRequestDurationP50, '0.5', '0.95'),
        k8sRequestDurationP99: std.strReplace(queries.k8sRequestDurationP50, '0.5', '0.99'),

        // Queues
        queueDepth: |||
          sum(
            argo_workflows_queue_depth_gauge{
              %(default)s
            }
          ) by (queue_name)
        ||| % controllerFilters,

        queueAdds: |||
          sum(
            rate(
              argo_workflows_queue_adds_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (queue_name)
        ||| % controllerFilters,

        queueLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_queue_latency_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le, queue_name)
          )
        ||| % controllerFilters,
        queueLatencyP95: std.strReplace(queries.queueLatencyP50, '0.5', '0.95'),

        queueDurationP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_queue_duration_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le, queue_name)
          )
        ||| % controllerFilters,
        queueDurationP95: std.strReplace(queries.queueDurationP50, '0.5', '0.95'),

        queueRetries: |||
          sum(
            rate(
              argo_workflows_queue_retries{
                %(default)s
              }[$__rate_interval]
            )
          ) by (queue_name)
        ||| % controllerFilters,

        queueLongestRunning: |||
          max(
            argo_workflows_queue_longest_running{
              %(default)s
            }
          ) by (queue_name)
        ||| % controllerFilters,

        queueUnfinishedWork: |||
          sum(
            argo_workflows_queue_unfinished_work{
              %(default)s
            }
          ) by (queue_name)
        ||| % controllerFilters,

        // Workers
        workersBusyCount: |||
          sum(
            argo_workflows_workers_busy_count{
              %(default)s
            }
          ) by (worker_type)
        ||| % controllerFilters,

        // Rate Limiter
        clientRateLimiterLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_client_rate_limiter_latency_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % controllerFilters,
        clientRateLimiterLatencyP95: std.strReplace(queries.clientRateLimiterLatencyP50, '0.5', '0.95'),

        resourceRateLimiterLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                argo_workflows_resource_rate_limiter_latency_bucket{
                  %(default)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % controllerFilters,
        resourceRateLimiterLatencyP95: std.strReplace(queries.resourceRateLimiterLatencyP50, '0.5', '0.95'),

      };

      local panels = {
        controllerErrorRateStat:
          mixinUtils.dashboards.statPanel(
            'Controller Errors',
            'ops',
            queries.controllerErrorRate,
            description='Current controller error rate across the selected controllers. Use this as the first signal for reconciliation failures.',
          ),

        k8sRequestSuccessRateStat:
          mixinUtils.dashboards.statPanel(
            'K8s API Success Rate',
            'percent',
            queries.k8sRequestSuccessRate,
            description='Current percentage of Kubernetes API requests succeeding. Drops here usually indicate API server issues, throttling, conflicts, or RBAC problems.',
          ),

        totalQueueDepthStat:
          mixinUtils.dashboards.statPanel(
            'Queue Depth',
            'short',
            queries.totalQueueDepth,
            description='Current total queue depth across controller work queues for the selected controllers.',
          ),

        totalBusyWorkersStat:
          mixinUtils.dashboards.statPanel(
            'Busy Workers',
            'short',
            queries.totalBusyWorkers,
            description='Current number of busy workers across the selected controllers.',
          ),

        // Errors
        errorCountByCauseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Controller Errors by Cause',
            'ops',
            queries.errorCountByCause,
            '{{ cause }}',
            description='Rate of controller errors by cause. Common causes include OperationPanic, CronWorkflowSubmissionError, and CronWorkflowSpecError. Persistent errors indicate controller-level issues requiring investigation.',
            stack='normal',
          ),

        logMessagesByLevelTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Log Messages by Level',
            'ops',
            queries.logMessagesByLevel,
            '{{ level }}',
            description='Rate of log messages by severity level. High rates of warning or error messages indicate controller issues. Debug/info messages show normal operation.',
            stack='normal',
          ),

        // K8s API
        k8sRequestRateByKindVerbTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'K8s API Request Rate by Kind/Verb',
            'ops',
            queries.k8sRequestRateByKindVerb,
            '{{ kind }}/{{ verb }}',
            description='Rate of Kubernetes API requests by resource kind and verb. High rates may indicate excessive reconciliation or API server pressure. Watch for throttling responses.',
            stack='normal',
          ),

        k8sRequestRateByStatusCodeTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'K8s API Request Rate by Status Code',
            'ops',
            queries.k8sRequestRateByStatusCode,
            '{{ status_code }}',
            description='Rate of Kubernetes API requests by HTTP status code. Non-2xx responses indicate API server issues, RBAC problems, or resource conflicts. Watch for 429 (throttled) and 5xx responses.',
            stack='normal',
          ),

        k8sRequestSuccessRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'K8s API Success Rate',
            'percent',
            [
              {
                expr: queries.k8sRequestSuccessRate,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of Kubernetes API requests succeeding. Drops here usually indicate API server issues, throttling, conflicts, or RBAC problems.',
            min=0,
            max=100,
          ),

        k8sRequestDurationTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'K8s API Request Duration',
            's',
            [
              {
                expr: queries.k8sRequestDurationP50,
                legend: 'P50',
              },
              {
                expr: queries.k8sRequestDurationP95,
                legend: 'P95',
              },
              {
                expr: queries.k8sRequestDurationP99,
                legend: 'P99',
              },
            ],
            description='Kubernetes API request latency percentiles. Rising latency indicates API server overload or network issues. P99 spikes often precede visible degradation of workflow processing.',
          ),

        // Queues
        queueDepthTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Depth',
            'short',
            queries.queueDepth,
            '{{ queue_name }}',
            description='Current depth of controller work queues. Rising depth indicates the controller cannot keep up with incoming work. Persistently high values suggest scaling issues.',
            stack='normal',
          ),

        queueAddsTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Additions',
            'ops',
            queries.queueAdds,
            '{{ queue_name }}',
            description='Rate of items being added to controller work queues. Spikes indicate bursts of workflow activity or reconciliation events.',
            stack='normal',
          ),

        queueLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Latency',
            's',
            [
              {
                expr: queries.queueLatencyP50,
                legend: '{{ queue_name }} P50',
              },
              {
                expr: queries.queueLatencyP95,
                legend: '{{ queue_name }} P95',
              },
            ],
            description='Time items wait in the queue before being processed. Rising latency indicates the controller is falling behind. High P95 values mean some items are waiting significantly longer than average.',
          ),

        queueDurationTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Processing Duration',
            's',
            [
              {
                expr: queries.queueDurationP50,
                legend: '{{ queue_name }} P50',
              },
              {
                expr: queries.queueDurationP95,
                legend: '{{ queue_name }} P95',
              },
            ],
            description='Time taken to process each queue item. Rising duration indicates complex workflows or slow API responses. High P95 may cause cascading delays.',
          ),

        queueRetriesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Retries',
            'ops',
            queries.queueRetries,
            '{{ queue_name }}',
            description='Rate of queue message retries. Frequent retries indicate transient failures in workflow processing. Persistent high rates suggest systemic issues.',
            stack='normal',
          ),

        queueLongestRunningTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Longest Running Processor',
            's',
            queries.queueLongestRunning,
            '{{ queue_name }}',
            description='Duration of the longest running queue processor. Very high values indicate stuck or slow processing that may be blocking other work.',
          ),

        queueUnfinishedWorkTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Queue Unfinished Work',
            'short',
            queries.queueUnfinishedWork,
            '{{ queue_name }}',
            description='Number of queue items that have not finished processing. Rising values indicate processing backlog.',
            stack='normal',
          ),

        // Workers
        workersBusyCountTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Busy Workers',
            'short',
            queries.workersBusyCount,
            '{{ worker_type }}',
            description='Number of busy queue workers by type. When all workers are busy, new items must wait. Consider increasing worker count if consistently saturated.',
            stack='normal',
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
            panels.controllerErrorRateStat,
            panels.k8sRequestSuccessRateStat,
            panels.totalQueueDepthStat,
            panels.totalBusyWorkersStat,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          row.new('Errors') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.errorCountByCauseTimeSeries,
            panels.logMessagesByLevelTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          row.new('Kubernetes API') +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.k8sRequestRateByKindVerbTimeSeries,
            panels.k8sRequestDurationTimeSeries,
            panels.k8sRequestRateByStatusCodeTimeSeries,
            panels.k8sRequestSuccessRateTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=15
        ) +
        [
          row.new('Work Queues') +
          row.gridPos.withX(0) +
          row.gridPos.withY(31) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.queueDepthTimeSeries,
            panels.queueAddsTimeSeries,
            panels.queueLatencyTimeSeries,
            panels.queueDurationTimeSeries,
            panels.queueRetriesTimeSeries,
            panels.queueLongestRunningTimeSeries,
            panels.queueUnfinishedWorkTimeSeries,
            panels.workersBusyCountTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=32
        );


      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Argo Workflows / Controller',
      ) +
      dashboard.withDescription('Detailed controller monitoring for Argo Workflows. Tracks controller errors, Kubernetes API request patterns, work queue metrics (depth, latency, duration, retries), worker saturation, rate limiter behavior, CronWorkflow triggers, and deprecated feature usage. Use this dashboard to diagnose controller performance issues, identify API server pressure, and monitor processing backlogs. %s' % mixinUtils.dashboards.dashboardDescriptionLink('argo-workflows-mixin', 'https://github.com/adinhodovic/argo-workflows-mixin')) +
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
        mixinUtils.dashboards.annotations($._config, controllerFilters)
      ),
  },
}
