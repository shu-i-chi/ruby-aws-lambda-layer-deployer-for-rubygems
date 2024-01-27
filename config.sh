# AWS Lambda Layer Settings
#   * Modify Gemfile too to install desired RubyGems.

# lambda_layer_name="rubygems-mysql"
# lambda_layer_description="RubyGem 'ruby-mysql' 4.1.0: https://rubygems.org/gems/ruby-mysql/versions/4.1.0"

# compatible_runtimes=("ruby3.2") # Use a space ' ' as a delimiter; "ruby2.7" "ruby3.2"
# compatible_architectures=("x86_64" "arm64") # Use a space ' ' as a delimiter; "x86_64" "arm64"

# Script Settings
#   * Normally there is no need to change the values.
#   * Place the Script Settings values AFTER AWS Lambda Layer Setting.

rubygems_build_dirname="built_rubygems" # Specify this directory in .gitignore.
zip_filename="${lambda_layer_name}.zip"
