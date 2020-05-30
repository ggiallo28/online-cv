REGION=eu-west-1
PREFIXNAME=online-cv

ts := $(shell /bin/date "+%Y-%m-%d-%H-%M-%S")
.create:
	@echo "Stack does not exists, create it."
	aws cloudformation create-stack --stack-name $(STACK_NAME) \
		--template-body $(TEMPLATE_BODY) \
		--region $(REGION) --capabilities CAPABILITY_NAMED_IAM \
		--parameters $(PARAMETERS) \
		--enable-termination-protection --output text && \
	aws cloudformation wait stack-create-complete --stack-name $(STACK_NAME) --region $(REGION)

.change:
	@echo "Stack exists, update it."
	@aws cloudformation create-change-set --stack-name $(STACK_NAME) \
		--template-body $(TEMPLATE_BODY) \
		--region $(REGION) --capabilities CAPABILITY_NAMED_IAM \
		--parameters $(PARAMETERS) \
		--change-set-name Update-$(ts) && \
	aws cloudformation wait change-set-create-complete --change-set-name Update-$(ts) \
		--stack-name $(STACK_NAME) --region $(REGION) && \
	aws cloudformation describe-change-set --change-set-name Update-$(ts) \
		--stack-name $(STACK_NAME) --region $(REGION)
	@echo "Do you want to apply the changes? [y/N] "
	@read answer; \
	[[ $$answer == y* ]] && \
		aws cloudformation execute-change-set --change-set-name Update-$(ts) --stack-name $(STACK_NAME) --region $(REGION) || \
		aws cloudformation delete-change-set --change-set-name Update-$(ts) --stack-name $(STACK_NAME) --region $(REGION)

pipeline:
	aws cloudformation describe-stacks --stack-name $(PREFIXNAME)-pipeline --region $(REGION) && \
	make .change \
		STACK_NAME=$(PREFIXNAME)-pipeline \
		PARAMETERS=file://cloudformation.json \
		TEMPLATE_BODY=file://cloudformation.yaml || \
	make .create \
		STACK_NAME=$(PREFIXNAME)-pipeline \
		PARAMETERS=file://cloudformation.json \
		TEMPLATE_BODY=file://cloudformation.yaml ;

