---
layout: post
title: "Kubernetes Monitoring with Prometheus and Grafana"
date: 2025-07-22 16:45:00 +0000
categories: [devops, kubernetes, monitoring]
tags: [kubernetes, prometheus, grafana, monitoring, observability]
author: "Your Name"
excerpt: "Learn how to set up comprehensive monitoring for your Kubernetes clusters using Prometheus and Grafana for better observability and alerting."
---

Monitoring is crucial for maintaining healthy Kubernetes clusters. Prometheus and Grafana provide a powerful combination for collecting metrics, creating dashboards, and setting up alerts. In this guide, we'll set up a complete monitoring stack for your Kubernetes cluster.

## Why Prometheus and Grafana?

**Prometheus** excels at:
- Time-series data collection
- Powerful query language (PromQL)
- Built-in alerting capabilities
- Kubernetes-native integration

**Grafana** provides:
- Beautiful, customizable dashboards
- Multiple data source support
- Advanced visualization options
- Alert management and notifications

## Architecture Overview

Our monitoring stack consists of:

- **Prometheus Server**: Collects and stores metrics
- **Node Exporter**: Exposes hardware and OS metrics
- **kube-state-metrics**: Kubernetes object state metrics
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and management

## Prerequisites

- Running Kubernetes cluster
- `kubectl` configured
- Helm 3.x installed

## Installation with Helm

We'll use the Prometheus Community Helm charts for easy installation:

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring
```

### Install Prometheus Stack

```bash
# Install kube-prometheus-stack (includes Prometheus, Grafana, and Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml
```

Create a `prometheus-values.yaml` file:

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "standard"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    retention: 30d
    
grafana:
  adminPassword: "admin123"
  persistence:
    enabled: true
    storageClassName: "standard"
    size: 1Gi
  
  # Enable anonymous access for demo (disable in production)
  grafana.ini:
    auth.anonymous:
      enabled: true
      org_role: Viewer

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: "standard"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi

# Enable additional exporters
nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

# Service monitors for additional services
additionalServiceMonitors:
  - name: "nginx-ingress"
    selector:
      matchLabels:
        app.kubernetes.io/name: ingress-nginx
    endpoints:
    - port: prometheus
```

## Manual Installation (Alternative)

If you prefer manual installation:

### Deploy Prometheus

```yaml
# prometheus-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        ports:
        - containerPort: 9090
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=30d'
          - '--web.enable-lifecycle'
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: prometheus-storage
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
```

### Prometheus Configuration

```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files:
      - "kubernetes-rules.yml"

    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093

    scrape_configs:
      # Kubernetes API server
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      # Kubernetes nodes
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)

      # Kubernetes pods
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
```

## Accessing the Services

### Port Forward Method

```bash
# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

### Ingress Method (Recommended for Production)

```yaml
# monitoring-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - prometheus.yourdomain.com
    - grafana.yourdomain.com
    - alertmanager.yourdomain.com
    secretName: monitoring-tls
  rules:
  - host: prometheus.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
  - host: grafana.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
  - host: alertmanager.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-alertmanager
            port:
              number: 9093
```

## Essential Dashboards

### Importing Grafana Dashboards

Popular dashboard IDs from grafana.com:

- **Kubernetes Cluster Overview**: 7249
- **Node Exporter Full**: 1860
- **Kubernetes Pod Overview**: 6417
- **Kubernetes Deployment**: 8588

```bash
# Import via API
curl -X POST \
  http://admin:admin123@localhost:3000/api/dashboards/import \
  -H 'Content-Type: application/json' \
  -d '{
    "dashboard": {
      "id": 7249,
      "title": "Kubernetes Cluster Overview"
    },
    "overwrite": true
  }'
```

### Custom Dashboard Example

```json
{
  "dashboard": {
    "title": "Application Metrics",
    "panels": [
      {
        "title": "Pod CPU Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{pod=\"my-app\"}[5m])",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Pod Memory Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{pod=\"my-app\"} / 1024 / 1024",
            "legendFormat": "{{pod}} MB"
          }
        ]
      }
    ]
  }
}
```

## Essential Alerts

### CPU and Memory Alerts

```yaml
# kubernetes-alerts.yaml
groups:
- name: kubernetes-alerts
  rules:
  - alert: PodCpuUsageHigh
    expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod CPU usage is above 80%"
      description: "Pod {% raw %}{{ $labels.pod }}{% endraw %} in namespace {% raw %}{{ $labels.namespace }}{% endraw %} has CPU usage above 80% for more than 5 minutes."

  - alert: PodMemoryUsageHigh
    expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod memory usage is above 90%"
      description: "Pod {% raw %}{{ $labels.pod }}{% endraw %} in namespace {% raw %}{{ $labels.namespace }}{% endraw %} has memory usage above 90% for more than 5 minutes."

  - alert: NodeDiskSpaceLow
    expr: (node_filesystem_free_bytes / node_filesystem_size_bytes) * 100 < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Node disk space is low"
      description: "Node {% raw %}{{ $labels.instance }}{% endraw %} has less than 10% disk space remaining."

  - alert: PodRestartingTooOften
    expr: rate(kube_pod_container_status_restarts_total[1h]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod is restarting too often"
      description: "Pod {% raw %}{{ $labels.pod }}{% endraw %} in namespace {% raw %}{{ $labels.namespace }}{% endraw %} has restarted more than once in the last hour."
```

## Alertmanager Configuration

```yaml
# alertmanager-config.yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@yourdomain.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@yourdomain.com'
    subject: '[ALERT] {% raw %}{{ .GroupLabels.alertname }}{% endraw %}'
    body: |
      {% raw %}{{ range .Alerts }}{% endraw %}
      Alert: {% raw %}{{ .Annotations.summary }}{% endraw %}
      Description: {% raw %}{{ .Annotations.description }}{% endraw %}
      {% raw %}{{ end }}{% endraw %}
  
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
    title: '[{% raw %}{{ .Status | toUpper }}{% endraw %}] {% raw %}{{ .GroupLabels.alertname }}{% endraw %}'
    text: '{% raw %}{{ range .Alerts }}{{ .Annotations.description }}{{ end }}{% endraw %}'
```

## Application Monitoring

### Adding Metrics to Your Application

For a Node.js application:

```javascript
const prometheus = require('prom-client');
const express = require('express');

// Create metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status']
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status']
});

// Middleware to collect metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode
    };
    
    httpRequestDuration.observe(labels, duration);
    httpRequestTotal.inc(labels);
  });
  
  next();
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

### Service Monitor for Custom Applications

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Best Practices

### Resource Management

```yaml
# Set resource limits for monitoring components
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 256Mi
```

### Security

- Use RBAC for service accounts
- Enable TLS for all communications
- Secure Grafana with authentication
- Limit network access with NetworkPolicies

### Data Retention

- Configure appropriate retention periods
- Use remote storage for long-term data
- Implement backup strategies

## Troubleshooting Common Issues

### Prometheus Not Scraping Targets

```bash
# Check service discovery
kubectl logs -n monitoring prometheus-pod-name

# Verify service monitor labels
kubectl get servicemonitor -n monitoring -o yaml

# Check network connectivity
kubectl exec -it prometheus-pod -- wget -O- target-service:port/metrics
```

### High Memory Usage

```bash
# Check memory metrics
promtool query instant 'prometheus_tsdb_head_samples_appended_total'

# Adjust retention or sample rate
--storage.tsdb.retention.time=15d
```

## Conclusion

Monitoring your Kubernetes clusters with Prometheus and Grafana provides essential visibility into your infrastructure and applications. This setup gives you:

- Real-time metrics and alerting
- Historical data for capacity planning
- Beautiful dashboards for various audiences
- Extensible architecture for custom metrics

Start with the basic setup and gradually add more sophisticated monitoring as your needs grow. Remember to secure your monitoring stack and implement proper backup strategies for production environments.

---

*Ready to dive deeper into Kubernetes observability? Check out my upcoming posts on distributed tracing and log aggregation!*
