# gRPC Kubernetes Deployment

## **Files in This Directory**
- `grpc-deployment.yaml`: Deployment configuration with health checks
- `grpc-service.yaml`: Service configuration for internal access

## **Deployment Commands**

### **1. Apply Both Configurations**
```bash
# Deploy to Kubernetes cluster
kubectl apply -f grpc-deployment.yaml -f grpc-service.yaml
```

Expected output:
```
deployment.apps/grpc-deployment created
service/grpc-service created
```

### **2. Verification Steps**

#### **Check Deployment Status**
```bash
kubectl get deployment grpc-deployment -o wide
```

Expected output:
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS        IMAGES                   SELECTOR
grpc-deployment   2/2     2            2           10s   grpc-container   your-grpc-image:latest   app=grpc-app
```

#### **Verify Pods Are Running**
```bash
kubectl get pods -l app=grpc-app
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
grpc-deployment-8658b8b5f7-abc12   1/1     Running   0          15s
grpc-deployment-8658b8b5f7-xyz34   1/1     Running   0          15s
```

#### **Check Service Endpoints**
```bash
kubectl get svc grpc-service
```

Expected output:
```
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
grpc-service    ClusterIP   10.96.123.456   <none>        50051/TCP   20s
```

#### **Test gRPC Health Checks**
```bash
# Install grpc_health_probe if needed
# kubectl exec -it <pod-name> -- grpc_health_probe -addr=:50051
```

