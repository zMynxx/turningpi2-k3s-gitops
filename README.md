# turningpi2-k3s-gitops
A GitOps repository for deployment to my k3s setup on turingpi2 using ArgoCD.

## Introduction
This repository contains the manifests needed to constuct my home kubernetes cluster using k3s on a TuringPi 2. The cluster is managed using ArgoCD for GitOps. The repository is structured in a way that it can be used to deploy the same setup on any k3s cluster.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Hardware](#hardware)
- [Node Slots](#node-slots)
- [Kubernetes Cluster](#kubernetes-cluster)
- [Folder Structure](#folder-structure)
- [ArgoCD](#argocd)
- [Minio](#minio)

## Prerequisites
- [k3s](https://k3s.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [kustomize](https://kustomize.io/)
- [helm](https://helm.sh/)

## Hardware
- [TuringPi 2](https://turingpi.com/turing-pi-2/)
- [2x Turing RK1 16GB Module](https://turingpi.com/turing-rk1/)
- [2x SanDisk SSD Plus 256GB](https://www.sandisk.com/home/ssd/ssd-plus)

## Node Slots
- Slot #1: Turing RK1 16GB Module 1
- Slot #2: Empty Slot
- Slot #3: Turing RK1 16GB Module 2 & 2xSanDisk SSD Plus 256GB 1
- Slot #4: Empty Slot

## Kubernetes Cluster
- 1x Master Node - Slot #3:
  Hostname: tpi2-rk1m-n01
  IP:       192.168.7.59
  OS:       Ubuntu 20.04.3 LTS
- 1x Worker Node - Slot #1:
  Hostname: tpi2-rk1m-n02
  IP:       192.168.7.58
  OS:       Ubuntu 20.04.3 LTS

## Folder Structure
```bash
.
├── app_of_apps      # AppOfApps manifests directory, to apply all the applications manifest it finds. 
├── app_project      # AppProject manifests directory, to set permissions and roles per project.
├── application_sets # Applications manifest generator.
├── applications     # Applications manifest for special cases.
├── infrastructure   # Infrastructure related resources like metallb, longhorn, etc.
├── kustomization    # Kustomization files for the applications.
├── tarballs         # Tarballs for the applications used. Backup if ever needed.
└── README.md
```

## ArgoCD
Fetch ArgoCD admin password:
```bash
kubectl --namespace argocd get secret argocd-initial-admin-secret --output jsonpath="{.data.password}" | base64 -decode | pbcopy
```

## Minio
Fetch Minio admin password:
```bash
kubectl --namespace minio-operator get secret console-sa-secret -o jsonpath="{.data.token}" | base64 --decode | pbcopy
```

## Longhorn
Longhorn is set up to backup into MinIO "backup" bucket (Endpoint: `s3://backup@local/`), credentails are stored in the vault under `/secret/longhorn/aws-secret`.
These aws credentials are in need of the corresponding IAM policy to be able to access the MinIO bucket:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::backup",
                "arn:aws:s3:::backup/*"
            ]
        }
    ]
}
```

