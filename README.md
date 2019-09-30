# Github AWS Account Vending Machine

This repository defines a Github AWS Account vending machine worker action.

## Concept

An organization will set up one Github repository that will represent an AWS
Organizations Root account and later the child accounts created for it. The
repository has this Github action handling Approvals of pull requests with
the following configuration:

```yaml
name: vend

on: pull_request_review

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - uses: NitorCreations/account-vending-machine@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        AWS_DEFAULT_REGION: eu-north-1
```

When a new account is required, the team in need will do as follows:
* Either clone or fork the repository
* Run a script that creates a branch and a [Nameless Deploy Tools](https://github.com/NitorCreations/nameless-deploy-tools)
  component with the same name
   * The script will also create the baseline CloudFormation/CDK/Serverless/Terraform subcomponents
     that implement things like consistent log forwarding, CloudTrail enabling and other security
     requirements
* Add any other basic components that the team needs and the team responsible for account management
  should review
* Create a pull request against master branch of the original repository

The team responsible for the account management will then review the pull request and once it gets
approved (you can configure a requirement for more than one approval with `APPROVALS` environment
variable - e.g. `APPROVALS=2` in the configuration above), the vending machine action will create
the account, and deploy all of the subcomponents in the account component. Once the PR is merged
to master, master will record all of the subcomponents created and the parameters used to create
them as well as details like the account id of the created account. The team can also enhance their
account later with other pull requests - the requirement is that the pull request source branch
matches the name of the account and the component containing the account subcomponents.

The worker will also run a script in the `ndt` parameter POST_CREATE if it is defined and an account
was created (not for subsequent pull requests for an existing account). This will enable for example
pushing Service Control policies onto the newly created account or recording values from dynamically
created resources into the git branch to be merged to master.

## Configuration

As you can see above the action requires that the checkout action is previously executed. The action
will need the github token to access the pull request details and login credentials to the AWS
organizations api. The AWS IAM user defined by the keys will have to have the `organizations:CreateAccount`
IAM permission.