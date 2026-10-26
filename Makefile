.PHONY: help test lint validate plan apply deploy destroy

help:            ## Show available targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

test:            ## Run application unit tests
	cd app && pip install -q -r requirements-dev.txt && pytest -q

lint:            ## Lint Python, Terraform formatting and Kubernetes manifests
	cd app && ruff check .
	terraform -chdir=terraform fmt -check -recursive
	kustomize build kubernetes | kubeconform -strict -summary -kubernetes-version 1.33.0 -

validate:        ## terraform init (no backend) + validate
	terraform -chdir=terraform init -backend=false -input=false
	terraform -chdir=terraform validate

plan:            ## Show the infrastructure plan
	terraform -chdir=terraform plan

apply:           ## Create the VPC, EKS cluster and ECR repository (~15-20 min)
	terraform -chdir=terraform apply

deploy:          ## Build, push and deploy the app to EKS
	./scripts/deploy.sh

destroy:         ## Remove the app and destroy all infrastructure
	./scripts/teardown.sh
