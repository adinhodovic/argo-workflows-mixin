{
  _config+:: {
    local this = self,

    argoWorkflowsSelector: 'job=~".*"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    grafanaUrl: 'https://grafana.com',

    dashboardIds: {
      'argo-workflows-overview': 'argo-workflows-overview-skj2',
      'argo-workflows-controller': 'argo-workflows-controller-skj2',
    },
    dashboardUrls: {
      'argo-workflows-overview': '%s/d/%s/argo-workflows-overview' % [this.grafanaUrl, this.dashboardIds['argo-workflows-overview']],
      'argo-workflows-controller': '%s/d/%s/argo-workflows-controller' % [this.grafanaUrl, this.dashboardIds['argo-workflows-controller']],
    },

    tags: ['argo-workflows', 'argo-workflows-mixin'],

    // Argo Workflows alert configuration
    alerts: {
      enabled: true,

      workflowFailureRate: {
        enabled: true,
        severity: 'warning',
        interval: '5m',
        threshold: '10',  // percent
      },

      workflowsPending: {
        enabled: true,
        severity: 'warning',
        interval: '15m',
        threshold: '5',  // number of pending workflows
      },

      controllerHighErrorRate: {
        enabled: true,
        severity: 'warning',
        interval: '5m',
        threshold: '5',  // errors per second
      },

      queueDepthHigh: {
        enabled: true,
        severity: 'warning',
        interval: '5m',
        threshold: '100',  // queue depth
      },

    },

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      tags: [],
      datasource: '-- Grafana --',
      iconColor: 'blue',
      type: 'tags',
    },
  },
}
