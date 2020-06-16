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

state:
	$(eval PIPENAME=$(shell aws cloudformation describe-stacks --stack-name $(PREFIXNAME)-pipeline --region $(REGION)\
		--query "Stacks[0].Outputs" | jq -r '.[] | select(.OutputKey=="PipelineName") | .OutputValue'))
	aws codepipeline get-pipeline-state --name $(PIPENAME) --region $(REGION)\
		--query "stageStates[*].{\
					STAGE:stageName,\
					ACTION:actionStates[0].actionName,\
					ID:latestExecution.pipelineExecutionId,\
					TOKEN:actionStates[0].latestExecution.token,\
					STATUS:latestExecution.status}"\
		--output table

approve:
	$(eval PIPENAME=$(shell aws cloudformation describe-stacks --stack-name $(PREFIXNAME)-pipeline --region $(REGION) --query "Stacks[0].Outputs" | jq -r '.[] | select(.OutputKey=="PipelineName") | .OutputValue'))
	$(eval JSON=$(shell aws codepipeline get-pipeline-state --name $(PIPENAME) --region $(REGION) --query\
					"{\
						pipelineName:pipelineName,\
						stageName:stageStates[?actionStates[0].latestExecution.token!=None].stageName|[0],\
						actionName:stageStates[?actionStates[0].latestExecution.token!=None].actionStates[0].actionName|[0],\
						token:stageStates[?actionStates[0].latestExecution.token!=None].actionStates[0].latestExecution.token|[0]\
					}" | jq '. + {"result": {"summary": "It Works","status": "Approved"}}'\
				))
	aws codepipeline put-approval-result --cli-input-json '$(JSON)' --region $(REGION)




			
