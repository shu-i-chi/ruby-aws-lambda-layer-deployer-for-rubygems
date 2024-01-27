# Ruby AWS Lambda Layer Deployer for RubyGems

English: [README.en.md](./README.en.md)

RubyGemsを指定して、AWS Lambda Layerをデプロイ（新規作成・更新）します。
RubyGemsのビルドは、AWS Lambda Rubyランタイムの公式Dockerコンテナ内で行います。

* https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html
* https://gallery.ecr.aws/lambda/ruby

## 目次

* [前提条件](#前提条件)
  * [対象RubyGems](#対象RubyGems)
  * [環境](#環境)
  * [ツール](#ツール)

* [使い方](#使い方)

* [仕組み](#仕組み)
  * [やること](#やること)
  * [スクリプト「`deploy-ruby-aws-lambda-layer-for-rubygems.sh`」の主要な動作ロジック](#スクリプトdeploy-ruby-aws-lambda-layer-for-rubygemsshの主要な動作ロジック)

## 前提条件

### 対象RubyGems

Gemfileに指定して`bundle install`できるRubyGems。

### 環境

* Bash

### ツール

* aws-cli
  * インストール手順：https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  * IAM権限：aws-cliが[`aws lambda publish-layer-version`](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/publish-layer-version.html)を実行できるようにしてください

* [Docker Engine](https://docs.docker.com/engine/)
  * インストール手順：https://docs.docker.com/engine/install/
    * CentOS：https://docs.docker.com/engine/install/centos/
    * Fedra：https://docs.docker.com/engine/install/fedora/
    * Ubuntu：https://docs.docker.com/engine/install/ubuntu/
    * Debian：https://docs.docker.com/engine/install/debian/
    * SLES：https://docs.docker.com/engine/install/sles/

## 使い方

例として、[ruby-mysql](https://rubygems.org/gems/ruby-mysql)をAWS Lambda Layerとしてデプロイします。

1. Gemfileに、AWS Lambda LayerとしたいRubyGemsを指定します

   ```ruby:Gemfile
   # frozen_string_literal: true

   source "https://rubygems.org"

   gem "ruby-mysql", "~> 4.1.0"
   ```

2. config.shに、デプロイするAWS Lambda Layerの設定をします：

   * `lambda_layer_name`：AWS Lambda Layer名
   * `lambda_layer_description`：AWS Lambda Layerの説明文
   * `compatible_runtimes`：AWS Lambda **Rubyランタイム**の互換性のあるバージョン
     * `"ruby3.2"`のように指定します
     * 複数指定する場合は、半角スペース` `で区切ってください（例：`"ruby2.7" "ruby3.2"`）
   * `compatible_architectures`：互換性のあるアーキテクチャ
     * `"x86_64"`、`"arm64"`のいずれか、あるいは両方を指定できます
     * 両方を指定する場合は、半角スペース` `で区切ってください（`"x86_64" "arm64"`）
     
   ```bash
   # AWS Lambda Layer Settings
   #   * Modify Gemfile too to install desired RubyGems.

   lambda_layer_name="rubygems-mysql"
   lambda_layer_description="RubyGem 'ruby-mysql' 4.1.0: https://rubygems.org/gems/ruby-mysql/versions/4.1.0"

   compatible_runtimes=("ruby3.2") # Use a space ' ' as a delimiter; "ruby2.7" "ruby3.2"
   compatible_architectures=("x86_64" "arm64") # Use a space ' ' as a delimiter; "x86_64" "arm64"
   ```

3. （必要な場合）Dockerfileに、RubyGemsをビルドするのに必要となるライブラリを追加します。

   AWS LambdaのRubyランタイムのDockerコンテナ内でビルドを行うので、
   あらかじめコンテナ作成時に`yum install -y <ライブラリ>`を加える必要があります。

   [Dockerfileの`RUN`](https://docs.docker.com/engine/reference/builder/#run)命令を使って、`RUN yum install -y <ライブラリ>`を追記してください：
   
   ```Dockerfile
   # Install additionally required libraries for building RubyGems
   RUN yum groupinstall -y "Development Tools"

   RUN yum install -y <ライブラリ1> # 追記
   RUN yum install -y <ライブラリ2> # 追記
   ```

4. スクリプト「`deploy-ruby-aws-lambda-layer-for-rubygems.sh`」を実行します：

   * 途中で、AWS Lambda Layerの設定内容確認のプロンプトを表示する場合（デフォルトの動作）：

     ```bash
     ./deploy-ruby-aws-lambda-layer-for-rubygems.sh
     ```
   
   * もしプロンプトをスキップしたい場合：

     オプション`-y`、`--yes`、あるいは`--skip-prompt`を指定して実行する。
   
     ```bash
     ./deploy-ruby-aws-lambda-layer-for-rubygems.sh -y
     ```

## 仕組み

スクリプト「`deploy-ruby-aws-lambda-layer-for-rubygems.sh`」は、種々のケアのため長大ですが、主要な動作ロジックは単純です。

### やること

AWS Lambda Layerは、AWS Lambdaランタイムの`/opt/`配下に配置されます。
また、AWS LambdaのRubyランタイムでは、RubyGemsを`require`するための参照パスのひとつ`GEM_PATH`に、パス`/opt/ruby/gems/3.2.0`（Ruby 3.2ランタイムの場合）が設定されています。

そこで、AWS Lambda Layerとしてデプロイするzipパッケージの構造を、**`ruby/gems/3.2.0/`配下にRubyGemsをインストールしたディレクトリ構成**にします：

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

（https://docs.aws.amazon.com/lambda/latest/dg/packaging-layers.html より引用；一部加工）

こうすれば、追加のパスの設定等をせずに、AWS Lambda Ruby関数内から`require`して呼び出すことができるようになります。

参考：https://docs.aws.amazon.com/lambda/latest/dg/packaging-layers.html

### スクリプト「`deploy-ruby-aws-lambda-layer-for-rubygems.sh`」の主要な動作ロジック

1. AWS LambdaのRubyランタイムのコンテナを起動する（関係するファイル：Dockerfile、docker-compose.yaml）

   * `ENTRYPOINT`は上書きする（そのままだと、コンテナ起動時にLambda関数を実行しようとするため）
   * RubyGemsのビルドに必要なライブラリは、あらかじめ`yum install`しておく
   * ビルドしたRubyGemsを格納するために、Dockerホスト（以下ローカル）のカレントディレクトリをマウントする

2. AWS LambdaのRubyランタイムのコンテナ内にはBundlerがインストールされているので、このBundlerを使って、RubyGemsをビルドする（関係するファイル：Gemfile）

   * `bundle install`する前に、あらかじめコンテナ内で`bundle config set --local path ./tmp`を行い、
     手順1でマウントしたローカルのカレントディレクトリ直下の`./tmp/`ディレクトリ内に、RubyGemsをビルドするように設定する

3. コンテナを停止する

   * ローカルのカレントディレクトリの`./tmp/`内に、RubyGemsがビルドされている状態になる

4. ビルドしたRubyGemsのディレクトリ構造を、AWS Lambda Layer用に変更する

   * 変更前：`./tmp/ruby/3.2.0/...`（Ruby 3.2ランタイムでビルドした場合）
   * 変更後：`./built_rubygems/ruby/gems/3.2.0/...`（作業の簡便さのために、`./tmp/`から`./built_rubygems/`に移動した）

5. 手順4の`./built_rubygems/ruby/gems/3.2.0/...`のディレクトリ`ruby/`以下を、zipパッケージにする

6. 手順5のzipパッケージを指定して、AWS Lambda Layerをデプロイする

   * aws-cliを使う場合、[`aws lambda publish-layer-version`](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/publish-layer-version.html)を使う

     * オプション`--zip-file`で、手順4のzipパッケージを指定する

     ```bash
     aws lambda publish-layer-version --layer-name <AWS Lambda Layer名> \
         --description <AWS Lambda Layer説明文> \
         --zip-file fileb://<zipパッケージパス> \
         --compatible-runtimes <互換性のあるAWS LambdaのRubyランタイムのバージョン> \
         --compatible-architectures <互換性のあるアーキテクチャ>
     ```
