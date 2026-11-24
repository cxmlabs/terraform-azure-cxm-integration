.PHONY: test

test:
	terraform fmt -check -recursive
	terraform init -backend=false -input=false
	terraform test
	terraform -chdir=examples/aks-access init -backend=false -input=false
	terraform -chdir=examples/aks-access validate
