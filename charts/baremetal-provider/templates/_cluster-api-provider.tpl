{{- define "capibm.manager" }}
{{ $arg := index . 0 }}
{{ $command := index . 1 }}
{{ $image := index . 2 }}
---
apiVersion: v1
kind: Secret
metadata:
  name: capbm-webhook-server-secret

---
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/port: "8443"
    prometheus.io/scheme: https
    prometheus.io/scrape: "true"
  labels:
    control-plane: controller-manager
    controller-tools.k8s.io: "1.0"
  name: capbm-controller-manager-metrics-svc
spec:
  ports:
  - name: https
    port: 8443
    targetPort: https
  selector:
    control-plane: controller-manager
    controller-tools.k8s.io: "1.0"

---
apiVersion: v1
kind: Service
metadata:
  labels:
    control-plane: controller-manager
    controller-tools.k8s.io: "1.0"
  name: capbm-controller-manager-service
spec:
  ports:
  - port: 443
  selector:
    control-plane: controller-manager
    controller-tools.k8s.io: "1.0"

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    control-plane: controller-manager
    controller-tools.k8s.io: "1.0"
  name: capbm-controller-manager
spec:
  selector:
    matchLabels:
      control-plane: controller-manager
      controller-tools.k8s.io: "1.0"
  serviceName: capbm-controller-manager-service
  template:
    metadata:
      labels:
        control-plane: controller-manager
        controller-tools.k8s.io: "1.0"
    spec:
      containers:
      - args:
        - --secure-listen-address=0.0.0.0:8443
        - --upstream=http://127.0.0.1:8080/
        - --logtostderr=true
        - --v=10
        image: gcr.io/kubebuilder/kube-rbac-proxy:v0.4.0
        name: kube-rbac-proxy
        ports:
        - containerPort: 8443
          name: https
      - args:
        - --metrics-addr=127.0.0.1:8080
        {{ $arg }}
        command:
        {{ $command }}
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: SECRET_NAME
          value: capbm-webhook-server-secret
        image: {{ $image }}
        imagePullPolicy: Always
        name: manager
        ports:
        - containerPort: 9876
          name: webhook-server
          protocol: TCP
        resources:
          limits:
            cpu: 100m
            memory: 30Mi
          requests:
            cpu: 100m
            memory: 20Mi
        volumeMounts:
        - mountPath: /tmp/cert
          name: cert
          readOnly: true
      terminationGracePeriodSeconds: 10
      volumes:
      - name: cert
        secret:
          defaultMode: 420
          secretName: capbm-webhook-server-secret
{{- end }}
