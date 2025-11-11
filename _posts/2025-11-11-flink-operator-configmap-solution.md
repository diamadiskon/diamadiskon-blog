---
layout: single
title: "Solving Flink Kubernetes Operator ConfigMap Conflicts: A GitOps Nightmare and Its Solution"
date: 2025-11-11 10:00:00 +0000
categories: [Apache Flink, Kubernetes, GitOps]
tags: [flink, kubernetes, operator, configmap, argocd, gitops, log4j, sync-waves]
author: Diamadis Konstantinids
excerpt: "Learn how to resolve the frustrating ConfigMap conflicts between Flink Kubernetes Operator and ArgoCD GitOps workflows, including the root cause analysis and a definitive sync wave orchestration solution."
header:
  overlay_color: "#000"
  overlay_filter: "0.5"
  overlay_image: /diamadiskon-blog/assets/images/1_gNTyuRCp8DiMe15itWQBjQ.png
  caption: "Solving Flink Kubernetes Operator ConfigMap conflicts in GitOps environments"
toc: true
toc_label: "Contents"
---

## The Problem: When Operators Fight GitOps

If you've ever tried to manage Flink applications using the Flink Kubernetes Operator in a GitOps environment with ArgoCD, you've likely encountered a frustrating scenario: your carefully crafted ConfigMaps keep going "out of sync" the moment your Flink pods start up. This article explores the root cause of this issue and provides a definitive solution.

### The Developer's Dilemma: Custom Logging Requirements

Developers working with Flink streaming applications often need to customize their logging configuration for several critical reasons:

- **Application-Specific Debug Levels**: Setting trace or debug levels for specific packages (`com.company.streaming.processors`, `org.apache.kafka`)
- **Custom Log Patterns**: Formatting logs to match company standards or integrate with centralized logging systems
- **Performance Monitoring**: Adding metrics-focused loggers for throughput, latency, and state size monitoring
- **Environment-Specific Configurations**: Different log levels for dev (DEBUG) vs. production (WARN) environments

The natural approach is to create a custom `log4j2.properties` file (since Log4j2 is Flink's default logging framework) and deploy it via GitOps. However, this is where the frustration begins: **the Flink Kubernetes Operator deploys its own default `log4j2.xml` configuration that overrides everything else**, completely ignoring developer customizations.

This creates a painful cycle where developers carefully craft their logging configurations, commit them to Git, watch ArgoCD sync them successfully, only to discover their pods are still using the operator's generic default logging setup. In a GitOps environment, this feels like a fundamental broken promise what you declare in Git should be what runs in production.

### The Setup

We had a typical enterprise streaming setup:

- **Flink Kubernetes Operator** managing FlinkDeployment resources
- **ArgoCD** for GitOps-based deployments
- **Custom log4j configuration** requiring hot-reload capabilities (monitorInterval=30)
- **Multiple environments** (dev, qa, prod) with consistent configuration patterns

### The Nightmare Scenario

Everything seemed perfect in our GitOps workflow until runtime:

1. ✅ ArgoCD syncs our FlinkDeployment successfully
2. ✅ ArgoCD syncs our custom ConfigMap with log4j configuration
3. ✅ Both resources show "Synced" status in ArgoCD UI
4. 🔄 FlinkDeployment starts creating pods...
5. ❌ **ConfigMap suddenly goes "OutOfSync" in ArgoCD**
6. 😤 Pod starts with wrong/default log4j configuration

```bash
# This was the frustrating cycle we experienced:
kubectl get configmap flink-config-my-streaming-app -o yaml
# Shows: lastAppliedConfiguration differs from desired state
```

### Root Cause Analysis: Operator vs. GitOps Philosophy

The issue stems from a fundamental conflict between two systems:

#### Flink Kubernetes Operator Behavior

- **ConfigMap-First Philosophy**: The operator automatically creates and manages ConfigMaps
- **Naming Convention**: Recognizes ConfigMaps with pattern `flink-config-<app-name>`
- **Auto-Generation**: Creates default configurations if none exist
- **Runtime Modifications**: Updates ConfigMaps during pod lifecycle events

#### The Technical Inconsistency: Default vs. Custom Configuration

The core technical problem lies in the **format and content mismatch** between what developers want and what the operator provides:

**Developer's Custom ConfigMap (log4j2.properties format):**

```yaml
data:
  log4j-console.properties: |
    monitorInterval=30
    rootLogger.level = INFO
    logger.myapp.name = com.company.streaming
    logger.myapp.level = DEBUG
    # Properties-based configuration
```

**Operator's Default ConfigMap (log4j2.xml format):**

```yaml
data:
  log4j-console.properties: |
    <?xml version="1.0" encoding="UTF-8"?>
    <Configuration>
      <Appenders>
        <Console name="console" target="SYSTEM_OUT">
          <PatternLayout pattern="%d{HH:mm:ss,SSS} %-5p %-60c %x - %m%n"/>
        </Console>
      </Appenders>
      <Loggers>
        <Root level="INFO">
          <AppenderRef ref="console"/>
        </Root>
      </Loggers>
    </Configuration>
```

#### The Operator's Aggressive Override Behavior

Every time a FlinkDeployment resource is modified or the operator performs reconciliation, it exhibits the following problematic behavior:

1. **Forced ConfigMap Recreation**: The operator **always** attempts to ensure its default log4j configuration exists
2. **Content Override**: If a ConfigMap with the expected name exists, the operator **replaces the content** with its default XML-based configuration
3. **Metadata Preservation Issues**: The operator modifies the ConfigMap but doesn't preserve the original `kubectl.kubernetes.io/last-applied-configuration` annotation
4. **Reconciliation Loops**: Any FlinkDeployment update (scaling, configuration changes, restarts) triggers this override behavior

This creates the "OutOfSync" scenario because:

- **ArgoCD Applied**: Custom properties-based log4j configuration
- **Operator Modified**: XML-based default configuration overwrites the custom one
- **ArgoCD Detects Drift**: The ConfigMap content no longer matches what's in Git
- **Annotation Mismatch**: `last-applied-configuration` differs from actual content

#### ArgoCD GitOps Expectations  

- **Declarative State**: Expects cluster state to match Git repository
- **Drift Detection**: Flags any runtime modifications as "OutOfSync"
- **Immutable Desired State**: Git is the single source of truth

### The "Obvious" Solutions That Don't Work

Before finding the real solution, we tried several approaches that seemed logical but failed:

#### ❌ Attempt 1: Embedding Configuration in Docker Images

```dockerfile
COPY env/nbg/config_common/log4j-console-common.properties ${FLINK_HOME}/conf/log4j-console.properties
```

**Result**: Operator-created ConfigMaps always override image-based configs.

#### ❌ Attempt 2: ArgoCD Ignore Annotations

```yaml
metadata:
  annotations:
    argocd.argoproj.io/compare-options: IgnoreExtraneous
    argocd.argoproj.io/sync-options: Prune=false
```

**Result**: Prevents ArgoCD from managing the resource properly.

#### ❌ Attempt 3: Embedded Configuration in FlinkDeployment

```yaml
spec:
  flinkConfiguration:
    log4j2-console.properties: |
      monitorInterval=30
      # ... configuration ...
```

**Result**: Operator still creates separate ConfigMaps that override embedded configs.

### The Solution: Sync Wave Orchestration

The breakthrough came from understanding that **timing is everything**. The solution uses ArgoCD sync waves to orchestrate the deployment order:

#### Strategy: FlinkDeployment First, ConfigMap Second

```yaml
# FlinkDeployment - Syncs FIRST
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # 🔑 Syncs first
  name: my-streaming-app
spec:
  # ... FlinkDeployment configuration ...
```

```yaml
# ConfigMap - Syncs SECOND  
apiVersion: v1
kind: ConfigMap
metadata:
  name: flink-config-my-streaming-app  # 🔑 Proper naming convention
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # 🔑 Syncs after FlinkDeployment
data:
  log4j-console.properties: |
    monitorInterval=30  # 🔑 Hot-reload capability
    # ... custom log4j configuration ...
```

### Why This Works: The Operator's Decision Logic

Understanding the operator's internal logic explains why this sequence succeeds:

1. **FlinkDeployment Created First** (sync-wave: "-1")
   - Operator detects new FlinkDeployment resource
   - Begins resource reconciliation process
   - **Does not immediately create ConfigMap** (no pods exist yet)

2. **ConfigMap Applied Second** (sync-wave: "0")
   - Custom ConfigMap with correct naming (`flink-config-<app-name>`) appears
   - Operator recognizes existing ConfigMap following its naming convention
   - **Adopts existing ConfigMap instead of creating new one**

3. **Pod Creation Phase**
   - Operator uses pre-existing ConfigMap for pod configuration
   - No runtime modifications needed = No ArgoCD drift detection
   - Hot-reload works via `monitorInterval=30`

### Implementation Details

#### Required ConfigMap Naming Convention

The ConfigMap **must** follow the Flink operator's naming pattern:

```yaml
metadata:
  name: flink-config-<app-name>
```

#### Critical Configuration Elements

```yaml
data:
  log4j-console.properties: |
    # Essential for hot-reload without pod restarts
    monitorInterval=30
    
    # Custom application loggers
    logger.myapp.name = com.example.streaming
    logger.myapp.level = TRACE
    # ... additional custom loggers ...
```

#### FlinkDeployment Integration

```yaml
metadata:
  annotations:
    # For hot-reload: DON'T use Stakater Reloader (it restarts pods)
    # configmap.reloader.stakater.com/reload: 'flink-config-my-streaming-app'
    
    # Only use sync wave for deployment ordering
    argocd.argoproj.io/sync-wave: "-1"
```

**Important**: The `configmap.reloader.stakater.com/reload` annotation **restarts pods** when ConfigMaps change, which defeats the purpose of log4j hot-reload. Choose either hot-reload OR Stakater Reloader, not both.

### Production Deployment Workflow

This solution enables a clean production workflow:

1. **Development**: Modify log4j configuration in Git repository
2. **GitOps Sync**: ArgoCD applies changes following sync wave order
3. **Hot Reload**: Configuration changes take effect within 30 seconds
4. **No Restarts**: Pods continue running, only log levels change
5. **Stable State**: ArgoCD shows everything "Synced" ✅

### Benefits of This Approach

#### ✅ **GitOps Compliance**

- Single source of truth in Git repository
- No manual interventions required
- Clean ArgoCD sync status

#### ✅ **Hot Configuration Reload**  

- Log level changes without pod restarts
- 30-second change detection interval
- Minimal service disruption

#### ✅ **Operator Compatibility**

- Works with Flink operator's design patterns
- Leverages operator's ConfigMap recognition logic
- No operator configuration changes required

#### ✅ **Multi-Environment Support**

- Consistent pattern across dev/qa/prod
- Environment-specific log level configurations
- Scalable to multiple Flink applications

### Alternative Approaches Explored

#### Operator-Level Configuration

The Flink Kubernetes Operator documentation suggests operator-level defaults:

```yaml
# In operator's values.yaml
defaultConfiguration:
  create: true
  append: true
  flink-conf.yaml: |+
    kubernetes.operator.dynamic.config.enabled: false
```

**Verdict**: This disables too much operator functionality and affects all deployments.

#### Resource-Level Operator Overrides

```yaml
spec:
  flinkConfiguration:
    kubernetes.operator.dynamic.config.enabled: 'false'
```

**Verdict**: Limited effectiveness; operator still creates ConfigMaps for log4j.

### Lessons Learned

#### 🎯 **Timing Matters in Kubernetes**

Sync waves aren't just for dependency ordering they can resolve resource ownership conflicts.

#### 🎯 **Understand Operator Patterns
**

Each operator has its own resource management philosophy. Work with it, not against it.

#### 🎯 **GitOps Requires Operator Awareness**

Not all operators are designed with GitOps in mind. Bridge the gap with orchestration strategies.

#### 🎯 **Hot-Reload is Achievable**

You can have both GitOps compliance and runtime configuration changes with the right architecture.

### Code Repository Structure

For reference, here's how we organized the solution:

```
manifests/dev/my-streaming-app/
├── templates/
│   ├── deployment.yaml                    # FlinkDeployment (sync-wave: "-1")  
│   ├── my-streaming-app-log4j-config.yaml  # ConfigMap (sync-wave: "0")
│   └── ... other resources
└── values.yaml
```

### Conclusion

The Flink Kubernetes Operator ConfigMap conflict represents a common challenge in modern Kubernetes environments: reconciling operator-driven automation with GitOps principles.

Our solution using ArgoCD sync waves to orchestrate resource creation timing demonstrates that with the right approach, you can achieve:

- ✅ **Stable GitOps workflows**
- ✅ **Hot configuration reload capabilities**  
- ✅ **Operator-friendly resource management**
- ✅ **Production-ready deployment patterns**

The key insight is understanding that Kubernetes operators make decisions based on the state they observe **at the moment of observation**. By controlling that timing through sync waves, we can influence operator behavior to align with our GitOps requirements.

This pattern is applicable beyond Flink any scenario where operators auto-generate resources that conflict with GitOps-managed configurations can benefit from strategic sync wave orchestration.

### The Human Factor: Why Engineering Intuition Matters

It's worth noting that this type of complex, multi-system interaction bug represents exactly the kind of problem that **requires human engineering insight and cannot be easily understood or analyzed by AI systems**. Here's why:

#### The Complexity of Operator Behavior Analysis

- **Timing-Dependent Logic**: The solution depends on understanding the precise sequence of operator decision-making during resource reconciliation
- **Implicit System Contracts**: Knowledge of how ArgoCD sync waves interact with Kubernetes operator lifecycle hooks isn't documented in any single place
- **Emergent Behavior**: The conflict emerges from the intersection of three independent systems (Flink Operator, ArgoCD, Kubernetes) each following their own design principles

This is a perfect example of why **human engineers remain irreplaceable** in complex distributed systems troubleshooting the ability to synthesize knowledge across multiple domains, recognize emergent patterns, and devise creative solutions that work with (rather than against) system behaviors.

### Related Resources

- [Flink Kubernetes Operator Documentation](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/operations/configuration/)
- [ArgoCD Sync Waves Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Kubernetes Operator Pattern Best Practices](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
