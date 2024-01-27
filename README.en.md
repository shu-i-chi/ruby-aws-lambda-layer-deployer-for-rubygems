# Ruby AWS Lambda Layer Deployer for RubyGems

Deploys an AWS Lambda Layer with RubyGems you specified.
RubyGems are built using an official AWS Lambda Ruby runtime Docker container.

* https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html
* https://gallery.ecr.aws/lambda/ruby

## Contents

* [Prerequisites](#prerequisites)
  * [Target RubyGems](#target-rubyGems)
  * [Environments](#environments)
  * [Tools](#tools)

* [Usage](#usage)

* [How to work](#how-to-work)
  * [What to do](#what-to-do)
  * [What the script `deploy-ruby-aws-lambda-layer-for-rubygems.sh` does](#what-the-script-deploy-ruby-aws-lambda-layer-for-rubygemssh-does)

## Prerequisites

### Target RubyGems

RubyGems which can be `bundle install`-ed with Gemfile.

### Environments

* Bash

### Tools

* aws-cli
  * Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  * IAM permissions: Configure IAM permissions which allows aws-cli to execute [`aws lambda publish-layer-version`](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/publish-layer-version.html).

* [Docker Engine](https://docs.docker.com/engine/)
  * Install: https://docs.docker.com/engine/install/
    * CentOS: https://docs.docker.com/engine/install/centos/
    * Fedra: https://docs.docker.com/engine/install/fedora/
    * Ubuntu: https://docs.docker.com/engine/install/ubuntu/
    * Debian: https://docs.docker.com/engine/install/debian/
    * SLES: https://docs.docker.com/engine/install/sles/

## Usage

Example: Deployes [ruby-mysql](https://rubygems.org/gems/ruby-mysql) as an AWS Lambda Layer.

1. Specify RubyGems which you want to deploy as an AWS Lambda Layer.

   ```ruby:Gemfile
   # frozen_string_literal: true

   source "https://rubygems.org"

   gem "ruby-mysql", "~> 4.1.0"
   ```

2. Edit config.sh for a deployed AWS Lambda Layer.

   * `lambda_layer_name`: The name of the AWS Lambda Layer
   * `lambda_layer_description`: The description of the AWS Lambda Layer
   * `compatible_runtimes`: The compatible AWS Lambda **Ruby runtime**versions
     * Specify like `"ruby3.2"`.
     * Use a space ` ` as a delimiter when you specify multiple runtime versions. (cf. `"ruby2.7" "ruby3.2"`)
   * `compatible_architectures`: The compatible architectures
     * Specify both or one of `"x86_64"` and `"arm64"`.
     * Use a spece ` ` as a delimiter when you specify multiple architectures. (cf. `"x86_64" "arm64"`)
     
   ```bash
   # AWS Lambda Layer Settings
   #   * Modify Gemfile too to install desired RubyGems.

   lambda_layer_name="rubygems-mysql"
   lambda_layer_description="RubyGem 'ruby-mysql' 4.1.0: https://rubygems.org/gems/ruby-mysql/versions/4.1.0"

   compatible_runtimes=("ruby3.2") # Use a space ' ' as a delimiter; "ruby2.7" "ruby3.2"
   compatible_architectures=("x86_64" "arm64") # Use a space ' ' as a delimiter; "x86_64" "arm64"
   ```

3. (When required) Add libraries needed to build RubyGems in Dockerfile.

   RubyGems are built in an AWS Lambda Ruby runtime Docker container.
   You should add libraries to build RubyGems when building Docker container's image with `yum install -y <libraries you need>` in Dockerfile.

   Use [Dockerfile `RUN`](https://docs.docker.com/engine/reference/builder/#run) instruction to add `yum install -y <libraries you need>`:
   
   ```Dockerfile
   # Install additionally required libraries for building RubyGems
   RUN yum groupinstall -y "Development Tools"

   RUN yum install -y <library 1> # Added
   RUN yum install -y <library 2> # Added
   ```

4. Run the script `deploy-ruby-aws-lambda-layer-for-rubygems.sh`:

   * (Default) With a prompt which confirms the AWS Lambda Layer settings:

     ```bash
     ./deploy-ruby-aws-lambda-layer-for-rubygems.sh
     ```
   
   * Skip the prompt which confirms the AWS Lambda Layer settings:

     Run the script with an option `-y`, `--yes`, or `--skip-prompt`.
   
     ```bash
     ./deploy-ruby-aws-lambda-layer-for-rubygems.sh -y
     ```

## How to work

Though there are many lines in the deploy script `deploy-ruby-aws-lambda-layer-for-rubygems.sh` for error handlings, it is very simple that it does.

### What to do

The content of an AWS Lambda Layer are loaded into the `/opt/` directory of an AWS Lambda function.
For each Ruby Lambda runtime, the environment variable `GEM_PATH` are set to include the `/opt/ruby/gems/3.2.0` (Ruby 3.2 runtime), which enables the Ruby function to `require` Ruby libraries.

So, make directory structures of a zip package for an AWS Lambda Layer to include installed RubyGems in the `ruby/gems/3.2.0`:

```bash
lambda_layer_json.zip
└ ruby/gems/3.2.0/
               | build_info
               | cache
               | doc
               | extensions
               | gems
               | └ json-2.7.0
               └ specifications
                 └ json-2.7.0.gemspec
```

(Referenced from https://docs.aws.amazon.com/lambda/latest/dg/packaging-layers.html; partially modified.)

With this zip package, you can create an AWS Lambda Layer of RubyGems which are `require`-ed from AWS Lambda Ruby functions without any additional Lambda function settings.

See also: https://docs.aws.amazon.com/lambda/latest/dg/packaging-layers.html

### What the script `deploy-ruby-aws-lambda-layer-for-rubygems.sh` does

1. Starts a Docker container of an AWS Lambda Ruby runtime. (Files: Dockerfile, docker-compose.yaml)

   * Overwrites `ENTRYPOINT`; as default, the container tries to execute a Lambda function when it starts.
   * `yum install` the libraries you need to build RubyGems in Dockerfile.
   * Mounts a local Docker host's current directory to the container to install RubyGems in it.

2. Builds RubyGems with Bundler which pre-installed in the AWS Lambda Ruby runtime. (Files: Gemfile)

   * Before `bundle install`,
     executes `bundle config set --local path ./tmp`
     in the container to make RubyGems be installed in the `./tmp/`.

3. Stops the container.

   * You now have the `./tmp`, in which RubyGems are installed.

4. Changes the directory structure of the built RubyGems for an AWS Lambda Layer.

   * From: `./tmp/ruby/3.2.0/...` (With Ruby 3.2 runtime)
   * To: `./built_rubygems/ruby/gems/3.2.0/...` (Changed the directory for convenience.)

5. Create a zip package of `./built_rubygems/ruby/`.

6. Deploy an AWS Lambda Layer with the zip package of the step 5.

   * With aws-cli, use [`aws lambda publish-layer-version`](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/publish-layer-version.html).

     * Specify the zip package of the step 4 with the option `--zip-file`.

     ```bash
     aws lambda publish-layer-version --layer-name <The name of the AWS Lambda Layer> \
         --description <The description of the AWS Lambda Layer> \
         --zip-file fileb://<The path of the zip package> \
         --compatible-runtimes <The compatible AWS Lambda Ruby runtime versions> \
         --compatible-architectures <The compatible architectures>
     ```
