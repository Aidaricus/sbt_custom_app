#!/bin/bash

set -e

APP_NAME="custom-app"
APP_PATH="./app"
DEPLOYMENT_NAME="app-deployment"
DEPLOYMENT_FILE="k8s/deployment.yaml"

# Запуск Minikube
minikube start --driver=docker

# Использование Docker внутри Minikube
eval $(minikube docker-env)

# Сборка Docker-образа
docker build -t $APP_NAME:latest $APP_PATH

# Установка imagePullPolicy: Never, если не указано
if ! grep -q "imagePullPolicy:" $DEPLOYMENT_FILE; then
  sed -i '/image: custom-app:latest/a \        imagePullPolicy: Never' $DEPLOYMENT_FILE
fi

# Применение манифестов Kubernetes
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/daemonset.yaml
kubectl apply -f k8s/cronjob.yaml

# Ожидание готовности новых подов
NEW_RS=$(kubectl get rs -l app=$APP_NAME -o jsonpath="{.items[-1:].metadata.name}")
PODS=$(kubectl get pods -l app=$APP_NAME -o jsonpath="{.items[?(@.metadata.ownerReferences[0].name=='$NEW_RS')].metadata.name}")

for pod in $PODS; do
  kubectl wait --for=condition=Ready pod/$pod --timeout=60s || {
    kubectl describe pod $pod
    kubectl logs $pod
    exit 1
  }
done

# Port-forward для доступа к приложению
kubectl port-forward service/app-service 8080:80 &
PORT_FORWARD_PID=$!
sleep 5

# Тестирование эндпоинтов
curl -s http://localhost:8080
curl -s http://localhost:8080/status
curl -s -X POST http://localhost:8080/log -H "Content-Type: application/json" -d '{"message": "test log"}'
curl -s http://localhost:8080/logs

# Проверка логов DaemonSet
kubectl logs $(kubectl get pods -l app=log-agent -o jsonpath='{.items[0].metadata.name}') | tail -5

# Принудительный запуск CronJob
kubectl create job --from=cronjob/log-archiver test-job
kubectl wait --for=condition=complete job/test-job --timeout=60s
kubectl logs $(kubectl get pods -l job-name=test-job -o jsonpath='{.items[0].metadata.name}')

# Завершение port-forward
kill $PORT_FORWARD_PID