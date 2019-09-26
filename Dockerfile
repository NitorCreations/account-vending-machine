FROM debian:9.6-slim

LABEL "com.github.actions.name"="Vend an AWS account when a Pull Request is approverd"
LABEL "com.github.actions.description"="Implements a workflow for an account vending machine when a pull request describing the new account details is approved"
LABEL "com.github.actions.icon"="cloud"
LABEL "com.github.actions.color"="blue"

LABEL version="0.0.1"
LABEL repository="http://github.com/NitorCreations/account-vending-machine"
LABEL homepage="http://github.com/NitorCreations/account-vending-machine"
LABEL maintainer="Pasi Niemi <pasi.niemi@nitor.com>"

RUN apt-get update && apt-get install -y curl jq git python-pip && \
    pip install nameless-deploy-tools

ADD vend.sh /vend.sh
ENTRYPOINT ["/vend.sh"]
