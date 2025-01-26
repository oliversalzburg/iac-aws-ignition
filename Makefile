docs:
	cd terraform; terraform-docs markdown table --output-file ../README.md --output-mode inject .

lock:
	terraform -chdir=terraform init -upgrade -backend=false

pretty:
	terraform -chdir=terraform fmt -recursive .

validate:
	terraform -chdir=terraform validate
