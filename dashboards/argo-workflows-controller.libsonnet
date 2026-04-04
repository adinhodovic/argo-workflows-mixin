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
      local queries = {
        // Errors
        errorCountByCause: |||
          sum(
            rate(
              argo_workflows_error_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (cause)
        ||| % defaultFilters,

        logMessagesByLevel: |||
          sum(
            rate(
              argo_workflows_log_messages{
                %(default)s
              }[$__rate_interval]
            )
          ) by (level)
        ||| % defaultFilters,

        // K8s API
        k8sRequestRateByKindVerb: |||
          sum(
            rate(
              argo_workflows_k8s_request_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (kind, verb)
        ||| % defaultFilters,

        k8sRequestRateByStatusCode: |||
          sum(
            rate(
              argo_workflows_k8s_request_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (status_code)
        ||| % defaultFilters,

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
        ||| % defaultFilters,
        k8sRequestDurationP95: std.strReplace(queries.k8sRequestDurationP50, '0.5', '0.95'),
        k8sRequestDurationP99: std.strReplace(queries.k8sRequestDurationP50, '0.5', '0.99'),

        // Queues
        queueDepth: |||
          sum(
            argo_workflows_queue_depth_gauge{
              %(default)s
            }
          ) by (queue_name)
        ||| % defaultFilters,

        queueAdds: |||
          sum(
            rate(
              argo_workflows_queue_adds_count{
                %(default)s
              }[$__rate_interval]
            )
          ) by (queue_name)
        ||| % defaultFilters,

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
        ||| % defaultFilters,
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
        ||| % defaultFilters,
        queueDurationP95: std.strReplace(queries.queueDurationP50, '0.5', '0.95'),

        queueRetries: |||
          sum(
            rate(
              argo_workflows_queue_retries{
                %(default)s
              }[$__rate_interval]
            )
          ) by (queue_name)
        ||| % defaultFilters,

        queueLongestRunning: |||
          max(
            argo_workflows_queue_longest_running{
              %(default)s
            }
          ) by (queue_name)
        ||| % defaultFilters,

        queueUnfinishedWork: |||
          sum(
            argo_workflows_queue_unfinished_work{
              %(default)s
            }
          ) by (queue_name)
        ||| % defaultFilters,

        // Workers
        workersBusyCount: |||
          sum(
            argo_workflows_workers_busy_count{
              %(default)s
            }
          ) by (worker_type)
        ||| % defaultFilters,

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
        ||| % defaultFilters,
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
        ||| % defaultFilters,
        resourceRateLimiterLatencyP95: std.strReplace(queries.resourceRateLimiterLatencyP50, '0.5', '0.95'),

        // CronWorkflows
        cronWorkflowTriggered: |||
          sum(
            rate(
              argo_workflows_cronworkflows_triggered_total{
                %(default)s
              }[$__rate_interval]
            )
          ) by (name, namespace)
        ||| % defaultFilters,

        // Deprecated Features
        deprecatedFeatures: |||
          sum(
            rate(
              argo_workflows_deprecated_feature{
                %(default)s
              }[$__rate_interval]
            )
          ) by (feature)
        ||| % defaultFilters,
      };

      local panels = {
        // Errors
        errorCountByCauseTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Error Rate by Cause',
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
            'Queue Additions Rate',
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
            'Queue Retries Rate',
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

        // Rate Limiter
        rateLimiterLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Rate Limiter Latency',
            's',
            [
              {
                expr: queries.clientRateLimiterLatencyP50,
                legend: 'Client P50',
              },
              {
                expr: queries.clientRateLimiterLatencyP95,
                legend: 'Client P95',
              },
              {
                expr: queries.resourceRateLimiterLatencyP50,
                legend: 'Resource P50',
              },
              {
                expr: queries.resourceRateLimiterLatencyP95,
                legend: 'Resource P95',
              },
            ],
            description='Time spent waiting for client-side and resource rate limiters. High values indicate the controller is being throttled to protect the Kubernetes API server. May slow workflow processing.',
          ),

        // CronWorkflows
        cronWorkflowTriggeredTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'CronWorkflow Trigger Rate',
            'ops',
            queries.cronWorkflowTriggered,
            '{{ namespace }}/{{ name }}',
            description='Rate of CronWorkflow triggers by name and namespace. Use to verify scheduled workflows are firing as expected. Missing triggers indicate scheduling issues.',
            stack='normal',
          ),

        // Deprecated Features
        deprecatedFeaturesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Deprecated Feature Usage',
            'ops',
            queries.deprecatedFeatures,
            '{{ feature }}',
            description='Rate of deprecated feature usage. These features may be removed in future versions. Plan migration to supported alternatives.',
            stack='normal',
          ),
      };

      local rows =
        [
          row.new('Errors') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
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
          startY=1
        ) +
        [
          row.new('Kubernetes API') +
          row.gridPos.withX(0) +
          row.gridPos.withY(9) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.k8sRequestRateByKindVerbTimeSeries,
            panels.k8sRequestRateByStatusCodeTimeSeries,
            panels.k8sRequestDurationTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=10
        ) +
        [
          row.new('Work Queues') +
          row.gridPos.withX(0) +
          row.gridPos.withY(26) +
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
          startY=27
        ) +
        [
          row.new('Rate Limiting') +
          row.gridPos.withX(0) +
          row.gridPos.withY(59) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.rateLimiterLatencyTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=60
        ) +
        [
          row.new('CronWorkflows') +
          row.gridPos.withX(0) +
          row.gridPos.withY(68) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.cronWorkflowTriggeredTimeSeries,
            panels.deprecatedFeaturesTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=69
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
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
