# Kubernetes Job Overview

## What is a Job?
A Job is a Kubernetes workload type designed for executing temporary operations that automatically terminate after completion.

### Common Use Cases:
- Batch data processing
- Script execution
- Database backups or log cleanup

## How Jobs Work
- Creates one or more Pods to perform specified tasks
- When all Pods complete successfully, the Job is marked as "Complete"

## Job Specification Example

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
