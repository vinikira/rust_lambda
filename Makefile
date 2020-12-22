BIN_PATH=${PWD}/target/x86_64-unknown-linux-musl/release/bootstrap
AWS_ACCOUNT_ID=$(shell aws sts get-caller-identity --query Account --output text)

.PHONY: build
build:
	cross build --target x86_64-unknown-linux-musl --releaes

.PHONY: run
run:
	aws lambda invoke \
	--endpoint http://localhost:9001 \
	--no-sign-request --function-name=rust_lambda \
	--invocation-type=RequestResponse \
	--payload $(payload) output.json

.PHONY: run_on_aws
run_on_aws:
	aws lambda invoke \
		--function-name=rust_lambda \
		--invocation-type=RequestResponse \
		--payload $(payload) \
		output.json

.PHONY: local_lambda_up
local_lambda_up:
	docker run --rm \
	-e DOCKER_LAMBDA_STAY_OPEN=1 -p 9001:9001 \
	-v ${BIN_PATH}:/var/task/bootstrap:ro,delegated \
	lambci/lambda:provided main

.PHONY: create_role
create_role:
	aws iam create-role \
	--role-name lambda-basic-execution \
	--assume-role-policy-document '{"Statement": [{"Action": "sts:AssumeRole","Principal": {"Service": "lambda.amazonaws.com"},"Effect": "Allow"}],"Version": "2012-10-17"}'
	aws iam attach-role-policy \
	--role-name lambda-basic-execution \
	--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

.PHONY: deploy
deploy:
	zip -r9 -j bootstrap.zip ${BIN_PATH}
	aws lambda create-function \
		--function-name rust_lambda \
		--runtime provided \
		--role arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-basic-execution \
		--zip-file fileb://bootstrap.zip \
		--description "Simple Rust function" \
		--timeout 5 \
		--handler main
