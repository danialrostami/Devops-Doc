# Kubernetes Job Overview

## What is a Job?
A Job is a Kubernetes workload type designed for executing temporary operations that automatically terminate after completion.

### Common Use Cases:
- Batch data processing
- Script execution
- Database backups or log cleanup

### How Jobs Work
- Creates one or more Pods to perform specified tasks
- When all Pods complete successfully, the Job is marked as "Complete"

### Job Specification Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: example-job
spec:
  # Number of successful job completions required
  completions: 3
  
  # Maximum number of pods running simultaneously
  parallelism: 2
  
  # Maximum retry attempts to execute job before marking as failed job
  backoffLimit: 4
  
  # Maximum time in seconds the job can run
  activeDeadlineSeconds: 60
  
  # Automatically clean up pods 30s after completion
  ttlSecondsAfterFinished: 30
  
  template:
    spec:
      # Restart policy - Never means create new pod on failure
      restartPolicy: Never
      
      containers:
      - name: main
        image: busybox
        command: ["echo", "Hello from Kubernetes Job"]
        
        # Resource limits example (optional)
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
```
### Apply & Verify
```bash
kubectl apply -f hello-job.yaml -n devops
```
```bash
kubectl get jobs -n devops
```
```bash
NAME         COMPLETIONS   DURATION   AGE
hello-job    3/3           15s        1m
```
### Job Detail
```bash
kubectl describe job hello-job -n devops
```
### pods created by a job
```bash
kubectl get pods -l job-name=<job-name> -n devops 
```
### delete a job
```bash
kubectl delete job hello-job -n devops
```
#### `Note`: If TTL isn't set, Pods won't be automatically deleted with the Job
### Delete specific Job's Pods
```bash
kubectl delete pod -l job-name=<job-name>
```
---
## What is CronJob?
CronJob is a Kubernetes workload for scheduling Jobs to run at specific times/intervals, similar to Linux `cron` but with Kubernetes-native features.

### Key Use Cases:
- Scheduled batch processing
- Database backups
- Automated script execution

### Problems CronJob Solves
Replaces external scheduling tools by providing:

1. **Precise Scheduling**  
   Uses standard cron format (e.g., `"*/5 * * * *"` for every 5 minutes)

2. **History Control**  
   Configurable retention for successful/failed Jobs

3. **Native Automation**  
   Built-in Job management without manual intervention

#### `Time Zone Alignment`:
CronJob schedules use the timezone of the kube-controller-manager. Mismatches between your local timezone and the cluster's timezone will cause unexpected execution times.

### Basic Example
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:latest
            command: ["/bin/sh", "-c", "pg_dumpall > /backups/backup-$(date +%s).sql"]
          restartPolicy: OnFailure
```
### CronJob Specification Key Fields

| Field | Description | Default Value |
|-------|-------------|---------------|
| `schedule` | **Required**<br>Cron-formatted schedule (e.g., `"0 * * * *"` for hourly) | - |
| `concurrencyPolicy` | Controls concurrent Job execution:<br>- `Allow` (default): Multiple Jobs can run simultaneously<br>- `Forbid`: Skip new Job if previous is running<br>- `Replace`: Cancel running Job and start new one | `Allow` |
| `successfulJobsHistoryLimit` | Number of successful completed Jobs to retain<br>(Use `0` to disable retention) | `3` |
| `failedJobsHistoryLimit` | Number of failed completed Jobs to retain<br>(Use `0` to disable retention) | `1` |
| `startingDeadlineSeconds` | Optional timeout for late-starting Jobs | `None` |
| `timeZone` | Timezone name (e.g., `"America/New_York"`)<br>Requires Kubernetes 1.25+ | `Cluster's timezone` |
