FROM debian:9.6-slim

LABEL "com.github.actions.name"="Vend an AWS account when a Pull Request is approverd"
LABEL "com.github.actions.description"="Implements a workflow for an account vending machine when a pull request describing the new account details is approved"
LABEL "com.github.actions.icon"="cloud"
LABEL "com.github.actions.color"="blue"

LABEL version="0.0.1"
LABEL repository="http://github.com/NitorCreations/account-vending-machine"
LABEL homepage="http://github.com/NitorCreations/account-vending-machine"
LABEL maintainer="Pasi Niemi <pasi.niemi@nitor.com>"

RUN apt-get update && apt-get install -y curl jq git python-pip unzip && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs && \
    pip install nameless-deploy-tools && \
    curl -s https://releases.hashicorp.com/terraform/0.12.9/terraform_0.12.9_linux_amd64.zip -o terraform.zip && \
    unzip -d /usr/bin/ terraform.zip && rm terraform.zip && \
    npm install -g aws-cdk serverless
ADD vend.sh /vend.sh
WORKDIR /github/workspace
ENTRYPOINT ["/vend.sh"]
