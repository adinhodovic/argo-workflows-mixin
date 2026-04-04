rule {
  match {
    name = "ArgoWorkflowsHighWorkflowFailureRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoWorkflowsPendingWorkflows"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoWorkflowsControllerNotLeader"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoWorkflowsControllerHighErrorRate"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoWorkflowsQueueDepthHigh"
  }
  disable = ["promql/regexp"]
}

rule {
  match {
    name = "ArgoWorkflowsPodPendingHigh"
  }
  disable = ["promql/regexp"]
}
