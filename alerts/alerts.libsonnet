{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'argo-workflows',
        rules: if $._config.alerts.enabled then std.prune([
          if $._config.alerts.workflowFailureRate.enabled then {
            alert: 'ArgoWorkflowsHighWorkflowFailureRate',
            expr: |||
              (
                sum(
                  rate(
                    argo_workflows_total_count{
                      %(argoWorkflowsSelector)s,
                      phase=~"Failed|Error"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace)
                /
                sum(
                  rate(
                    argo_workflows_total_count{
                      %(argoWorkflowsSelector)s
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace)
                * 100
              ) > %(threshold)s
            ||| % (
              $._config
              {
                interval: $._config.alerts.workflowFailureRate.interval,
                threshold: $._config.alerts.workflowFailureRate.threshold,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.workflowFailureRate.severity,
            },
            annotations: {
              summary: 'Argo Workflows high workflow failure rate.',
              description: 'More than %(threshold)s%% of workflows are failing or erroring in {{ $labels.namespace }} the past %(interval)s.' % $._config.alerts.workflowFailureRate,
              dashboard_url: $._config.dashboardUrls['argo-workflows-overview'] + '?var-namespace={{ $labels.namespace }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.workflowsPending.enabled then {
            alert: 'ArgoWorkflowsPendingWorkflows',
            expr: |||
              sum(
                argo_workflows_gauge{
                  %(argoWorkflowsSelector)s,
                  phase="Pending"
                }
              ) by (%(clusterLabel)s, namespace)
              > %(threshold)s
            ||| % (
              $._config
              {
                threshold: $._config.alerts.workflowsPending.threshold,
              }
            ),
            'for': $._config.alerts.workflowsPending.interval,
            labels: {
              severity: $._config.alerts.workflowsPending.severity,
            },
            annotations: {
              summary: 'Argo Workflows has many pending workflows.',
              description: 'More than %(threshold)s workflows are pending in {{ $labels.namespace }} for the past %(interval)s.' % $._config.alerts.workflowsPending,
              dashboard_url: $._config.dashboardUrls['argo-workflows-overview'] + '?var-namespace={{ $labels.namespace }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.controllerHighErrorRate.enabled then {
            alert: 'ArgoWorkflowsControllerHighErrorRate',
            expr: |||
              sum(
                rate(
                  argo_workflows_error_count{
                    %(argoWorkflowsSelector)s
                  }[%(interval)s]
                )
              ) by (%(clusterLabel)s, cause)
              > %(threshold)s
            ||| % (
              $._config
              {
                interval: $._config.alerts.controllerHighErrorRate.interval,
                threshold: $._config.alerts.controllerHighErrorRate.threshold,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.controllerHighErrorRate.severity,
            },
            annotations: {
              summary: 'Argo Workflows controller has a high error rate.',
              description: 'More than %(threshold)s errors per second with cause {{ $labels.cause }} the past %(interval)s.' % $._config.alerts.controllerHighErrorRate,
              dashboard_url: $._config.dashboardUrls['argo-workflows-controller'] + clusterVariableQueryString,
            },
          },
          if $._config.alerts.queueDepthHigh.enabled then {
            alert: 'ArgoWorkflowsQueueDepthHigh',
            expr: |||
              sum(
                argo_workflows_queue_depth_gauge{
                  %(argoWorkflowsSelector)s
                }
              ) by (%(clusterLabel)s, queue_name)
              > %(threshold)s
            ||| % (
              $._config
              {
                threshold: $._config.alerts.queueDepthHigh.threshold,
              }
            ),
            'for': $._config.alerts.queueDepthHigh.interval,
            labels: {
              severity: $._config.alerts.queueDepthHigh.severity,
            },
            annotations: {
              summary: 'Argo Workflows controller queue depth is high.',
              description: 'Queue {{ $labels.queue_name }} has a depth of more than %(threshold)s for the past %(interval)s.' % $._config.alerts.queueDepthHigh,
              dashboard_url: $._config.dashboardUrls['argo-workflows-controller'] + clusterVariableQueryString,
            },
          },
        ]),
      },
    ],
  },
}
