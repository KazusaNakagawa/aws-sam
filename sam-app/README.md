# sam-app

Powertools provides three core utilities:

- **[Tracing](https://awslabs.github.io/aws-lambda-powertools-python/latest/core/tracer/)** - Decorators and utilities to trace Lambda function handlers, and both synchronous and asynchronous functions
- **[Logging](https://awslabs.github.io/aws-lambda-powertools-python/latest/core/logger/)** - Structured logging made easier, and decorator to enrich structured logging with key Lambda context details
- **[Metrics](https://awslabs.github.io/aws-lambda-powertools-python/latest/core/metrics/)** - Custom Metrics created asynchronously via CloudWatch Embedded Metric Format (EMF)

Find the complete project's [documentation here](https://awslabs.github.io/aws-lambda-powertools-python).

### Installing AWS Lambda Powertools for Python

With [pip](https://pip.pypa.io/en/latest/index.html) installed, run:

```bash
pip install aws-lambda-powertools
```

### Powertools Examples

- [Tutorial](https://awslabs.github.io/aws-lambda-powertools-python/latest/tutorial)
- [Serverless Shopping cart](https://github.com/aws-samples/aws-serverless-shopping-cart)
- [Serverless Airline](https://github.com/aws-samples/aws-serverless-airline-booking)
- [Serverless E-commerce platform](https://github.com/aws-samples/aws-serverless-ecommerce-platform)
- [Serverless GraphQL Nanny Booking Api](https://github.com/trey-rosius/babysitter_api)

### Deploy the sample application

The Serverless Application Model Command Line Interface (SAM CLI) is an extension of the AWS CLI that adds functionality for building and testing Lambda applications. It uses Docker to run your functions in an Amazon Linux environment that matches Lambda. It can also emulate your application's build environment and API.

To use the SAM CLI, you need the following tools.

- SAM CLI - [Install the SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
- [Python 3 installed](https://www.python.org/downloads/)
- Docker - [Install Docker community edition](https://hub.docker.com/search/?type=edition&offering=community)

To build and deploy your application for the first time, run the following in your shell:

## build & deploy

```bash
./sam_build.sh

./dev_sam_deploy.sh
```

### Cleanup

To delete the sample application that you created, use the AWS CLI. Assuming you used your project name for the stack name, you can run the following:

```bash
sam delete --stack-name "<Env>-sam-app"
```

## Resources

See the [AWS SAM developer guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) for an introduction to SAM specification, the SAM CLI, and serverless application concepts.

Next, you can use AWS Serverless Application Repository to deploy ready to use Apps that go beyond hello world samples and learn how authors developed their applications: [AWS Serverless Application Repository main page](https://aws.amazon.com/serverless/serverlessrepo/)
