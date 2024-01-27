#!/bin/bash

# Required commands/files/variables

required_commands=("aws" "docker")
required_files=("Dockerfile" "docker-compose.yaml" "Gemfile"
                "config.sh" "usage.sh")

required_aws_lambda_layer_settings_variables=( # defined in config.sh
  "lambda_layer_name"
  "lambda_layer_description"
  "compatible_runtimes"
  "compatible_architectures"
)

required_script_settings_variables=( # defined in config.sh
  "rubygems_build_dirname"
  "zip_filename"
)

# ---

# Output Decorations

c_g="\e[32m" # Color Green
c_r="\e[31m" # Color Red
c_y="\e[33m" # Color Yellow
c_k="\e[30m" # Color Black

bc_g="\e[42m" # Background Color Green
bc_r="\e[41m" # Background Color Red

f_b="\e[1m" # Font Bold
f_u="\e[4m" # Font Underscore

d_off="\e[m"  # Reset Decorations

ok_bar="${bc_g}${c_k} OK ${d_off}"
ng_bar="${bc_r}${c_k} NG ${d_off}"

# ---

# Functions

# Returns 0 if the variable is defined and set, otherwise returns 1.
check_if_variable_set() {
  local checked_variable_name="$1"
  test -n "${!checked_variable_name}"
}

echo_title() {
  local str="$1"

  echo ""
  echo -e "${f_b}${f_u}${str}${d_off}"
  echo ""
}

abort_this_script() {
  echo ""
  echo "Aborted this script."
  exit 1
}

# ---

cd "$(dirname $0)"

# Check arguments

skip_settings_confirmation_prompt="no"

if [[ $# -gt 2 || ($# -eq 1 && ($1 != "-y" && $1 != "--yes" && $1 != "--skip-prompt")) ]]; then
  source ./usage.sh
  exit 1
elif [[ $# -eq 1 && ($1 == "-y" || $1 == "--yes" || $1 == "--skip-prompt") ]]; then
  skip_settings_confirmation_prompt="yes"
fi

# Check prerequisites

## Commands and Files

### Commands

not_installed_commands=()

for command_name in "${required_commands[@]}"; do
  if ! command -v ${command_name} > /dev/null 2>&1; then
    not_installed_commands+=("${command_name}")
  fi
done

### Files

not_existing_files=()

for filename in "${required_files[@]}"; do
  if [[ ! -f "./${filename}" ]]; then
    not_existing_files+=("${filename}")
  fi
done

### Check Commands/Files

if [[ "${#not_installed_commands[*]}" -ne 0 || "${#not_existing_files[*]}" -ne 0 ]]; then
  echo_title "[0/5] Check the prerequisites."
  echo -e " -> ${ng_bar}"

  if [[ "${#not_installed_commands[*]}" -ne 0 ]]; then
    echo ""
    echo "    Install commands:"

    for command_name in "${not_installed_commands[@]}"; do
      echo -e "      x ${c_y}${command_name}${d_off}"
    done
  fi

  if [[ "${#not_existing_files[*]}" -ne 0 ]]; then
    echo ""
    echo "    Missing files:"

    for filename in "${not_existing_files[@]}"; do
      echo -e "      x ${c_y}./${filename}${d_off}"
    done
  fi

  abort_this_script
fi

source ./config.sh

## Variables for AWS Lambda Layer Settings

not_defined_aws_lambda_layer_settings_variables=()

for variable_name in "${required_aws_lambda_layer_settings_variables[@]}"; do
  if ! check_if_variable_set "${variable_name}"; then
    not_defined_aws_lambda_layer_settings_variables+=("${variable_name}")
  fi
done

### Check Variables

if [[ "${#not_defined_aws_lambda_layer_settings_variables[*]}" -ne 0 ]]; then
  echo_title "[0/5] Check the prerequisites."
  echo -e " -> ${ng_bar}"
  echo ""
  echo "    Undefined variables:"

  for variable_name in "${not_defined_aws_lambda_layer_settings_variables[@]}"; do
    echo -e "      x ${c_y}${variable_name}${d_off}"
  done

  echo ""
  echo -e "    Please check ${c_y}./config.sh${d_off}."

  abort_this_script
fi

## Variables for This Script Settings

not_defined_script_settings_variables=()

for variable_name in "${required_script_settings_variables[@]}"; do
  if ! check_if_variable_set "${variable_name}"; then
    not_defined_script_settings_variables+=("${variable_name}")
  fi
done

### Check Variables

if [[ "${#not_defined_script_settings_variables[*]}" -ne 0 ]]; then
  echo_title "[0/5] Check the prerequisites."
  echo -e " -> ${ng_bar}"
  echo ""
  echo "    Undefined variables:"

  for variable_name in "${not_defined_script_settings_variables[@]}"; do
    echo -e "      x ${c_y}${variable_name}${d_off}"
  done

  echo ""
  echo -e "    Please check ${c_y}./config.sh${d_off}."

  abort_this_script
fi

## Gemfile

installed_rubygems=()

while read line; do
  if [[ -n "${line}" ]]; then
    installed_rubygems+=("${line}")
  fi
done < <(cat ./Gemfile | sed -nE "s/^\s*gem\s+['\"]([[:alnum:]_-]+)['\"].*/\1/p")

### Check if one or more RubyGems are specified

if [[ "${#installed_rubygems[*]}" -eq 0 ]]; then
  echo_title "[0/5] Check the prerequisites."
  echo -e " -> ${ng_bar}"
  echo ""
  echo -e "    No RubyGems are specified in ${c_y}./Gemfile${d_off}."

  abort_this_script
fi

# Display RubyGems build info and settings for AWS Lambda Layer

echo -e "${c_r}=================================================================================================${d_off}"
echo ""
echo -e "${f_u}${f_b}RubyGems${d_off} specified in ${c_y}Gemfile${d_off}:"
echo ""
for installed_rubygem in "${installed_rubygems[@]}"; do
  echo -e "    * ${c_g}${installed_rubygem}${d_off}"
done

echo ""
echo -e "${f_u}${f_b}AWS Lambda Layer name${d_off} specified in ${c_y}./config.sh${d_off}:"
echo ""
cat ./config.sh | sed -nE "s/^lambda_layer_name\=['\"]([[:alnum:]_-]+)['\"]/    \1/p"

echo ""
echo -e "${f_u}${f_b}AWS Lambda Layer description${d_off} specified in ${c_y}./config.sh${d_off}:"
echo ""
cat ./config.sh | sed -nE "s/^lambda_layer_description\=['\"](.+)['\"]/    \1/p"

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo ""
echo -e "${f_u}${f_b}Libraries for building RubyGems${d_off} yum installed in the Docker container, specified in ${c_y}./Dockerfile${d_off}:"
echo ""
cat ./Dockerfile \
  | grep "^RUN" | grep -v "RUN yum install -y shadow-utils" \
  | sed "s/|/\n/g" | sed -E "s/^RUN\s+//" | sed -E "s/^\s*//" \
  | grep -E "yum install|groupinstall" | sed "s/^/    /"

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo ""
echo -e "${f_u}${f_b}Compatible Ruby runtime version${d_off} specified in ${c_y}config.sh${d_off}:"
echo ""
cat ./config.sh | sed -nE "s/^compatible_runtimes\=\((.+)\).*/    \1/p"

echo ""
echo -e "${f_u}${f_b}Docker container's Ruby version${d_off} specified in ${c_y}Dockerfile${d_off} for building RubyGems:"
echo ""
cat ./Dockerfile | sed -nE "s/^FROM (public\.ecr\.aws\/lambda\/ruby\:[[:digit:]]+\.[[:digit:]]+)$/    \1/p"

echo ""
echo -e "${c_r}=================================================================================================${d_off}"

echo ""
if [[ "${skip_settings_confirmation_prompt}" == "no" ]]; then
  echo -ne "${c_y}Are settings above OK? (y/n):${d_off} "
  read settings_confirmation_prompt_answer

  if [[ "${settings_confirmation_prompt_answer}" != "y" &&
          "${settings_confirmation_prompt_answer}" != "Y" ]]; then
    abort_this_script
  fi
fi

# 1. Clean up ./${zip_filename}, ./${rubygems_build_dirname}/, and ./.bundle/

echo_title "[1/5] Clean up ${c_y}./${zip_filename}${d_off}${f_b}${f_u}, ${c_y}./${rubygems_build_dirname}/${d_off}${f_b}${f_u}, and ${c_y}./.bundle/${d_off}${f_b}${f_u}."

if [[ -f ./"${zip_filename}" || -d ./"${rubygems_build_dirname}"/ || -d ./.bundle/ ]]; then
  if [[ -f ./"${zip_filename}" ]]; then
    rm ./"${zip_filename}"
    echo -e "    * Deleted existing ${c_y}./${zip_filename}${d_off}."
  else
    echo -e "    o ${c_y}./${zip_filename}${d_off} does not exist."
  fi

  if [[ -d ./"${rubygems_build_dirname}"/ ]]; then
    rm -rf ./"${rubygems_build_dirname}"/
    echo -e "    * Deleted existing ${c_y}./${rubygems_build_dirname}/${d_off}."
  else
    echo -e "    o ${c_y}./${rubygems_build_dirname}/${d_off} does not exist."
  fi

  if [[ -d ./.bundle/ ]]; then
    rm -rf ./.bundle/
    echo -e "    * Deleted existing ${c_y}./.bundle/${d_off}."
  else
    echo -e "    o ${c_y}./.bundle/${d_off} does not exist."
  fi
else
  echo -e "    o None of ${c_y}./${zip_filename}${d_off}, ${c_y}./${rubygems_build_dirname}/${d_off}, or ${c_y}./.bundle/${d_off} exists."
fi

echo ""
echo -e " -> ${ok_bar}"

# 2. Build RubyGems

echo_title "[2/5] Build RubyGems."

sudo docker compose build

if [[ $? -ne 0 ]]; then
  echo ""
  echo -e " -> ${ng_bar}"

  echo -e "    ${c_y}docker compose build${d_off} failed."
  echo ""
  echo -e "    You may fix ${c_y}./Dockerfile${d_off}."

  abort_this_script
fi

sudo docker compose up -d

sudo docker compose exec rubygems_builder bundle config set --local path ./tmp
sudo docker compose exec rubygems_builder bundle install

if [[ $? -ne 0 ]]; then
  echo ""
  echo -e " -> ${ng_bar}"

  echo -e "    Building RubyGems failed while executing ${c_y}bundle install${d_off}."

  echo ""
  echo -e "    Are the RubyGems' ${c_y}name${d_off} or ${c_y}specified versions${d_off} defined in ${c_y}./Gemfile${d_off} correct?"
  echo ""
  echo "      No ->"
  echo ""
  echo -e "        1. Fix ${c_y}./Gemfile${d_off}."
  echo -e "        2. Then ${c_y}execute this script${d_off} again."
  echo ""
  echo "      Yes ->"
  echo ""
  echo "        Some libraries to build RubyGems are missing in the docker container."
  echo -e "        ${c_y}Find what libraries you need${d_off}, and ${c_y}add their installation in ${f_u}./Dockerfile${d_off}."
  echo ""
  echo "          1. Inspect additionally required libraries for RubyGems."
  echo ""
  echo "             1-1. Start a container manually and login:"
  echo -e "                    ${c_y}sudo docker compose up -d"
  echo -e "                    ${c_y}sudo docker compose exec --user root rubygems_builder /bin/bash${d_off}"
  echo ""
  echo "             1-2. Set bundler to bundle install locally:"
  echo -e "                    ${c_y}bundle config set --local path ./tmp${d_off}"
  echo ""
  echo "             1-3. Try to success bundle install and find what libraries you need:"
  echo -e "                    ${c_y}bundle install${d_off} # -> Error"
  echo "                    # -> Inspect build errors..."
  echo -e "                    ${c_y}sudo yum install -y <some libraries>${d_off}"
  echo -e "                    # Try ${c_y}bundle install${d_off} again..."
  echo ""
  echo "             1-4. Stop the container:"
  echo -e "                    ${c_y}sudo docker compose down${d_off}"
  echo ""
  echo -e "       2. Edit ${c_y}./Dockerfile${d_off} to add"
  echo -e "          some '${c_y}RUN yum install -y <some required libraries for RubyGems>${d_off}' lines."

  echo ""
  sudo docker compose down

  abort_this_script
fi

sudo docker compose exec rubygems_builder mkdir -p ./"${rubygems_build_dirname}"/ruby
sudo docker compose exec rubygems_builder mv ./tmp/ruby ./"${rubygems_build_dirname}"/ruby/gems

sudo docker compose exec rubygems_builder rm -rf ./tmp/
sudo docker compose exec rubygems_builder rm ./Gemfile.lock

sudo docker compose down

if [[ -d ./"${rubygems_build_dirname}"/ && \
        "$(find ./${rubygems_build_dirname}/ -type f | wc -l)" -ne 0 ]]; then
  echo ""
  echo -e " -> ${ok_bar}"
  echo -e "    Building RubyGems in ${c_y}./${rubygems_build_dirname}/${d_off} completed."
else
  echo ""
  echo -e " -> ${ng_bar}"
  echo -e "    Building RubyGems failed in ${c_y}./${rubygems_build_dirname}/${d_off}."

  abort_this_script
fi

# 3. Zip built RubyGems directories

echo_title "[3/5] Zip RubyGmes."

cd ./"${rubygems_build_dirname}"/
zip -rq ../"${zip_filename}" ruby/
cd ..

if [[ -f ./"${zip_filename}" ]]; then
  echo -e " -> ${ok_bar}"
  echo -e "    Zipped RubyGems in ${c_y}./${zip_filename}${d_off}."
else
  echo -e " -> ${ng_bar}"
  echo "    Zipping RubyGems failed."

  abort_this_script
fi

# 4. Upload on AWS Lambda

echo_title "[4/5] Update AWS Lambda Layer."

aws lambda publish-layer-version --layer-name "${lambda_layer_name}" \
    --description "${lambda_layer_description}" \
    --zip-file fileb://"${zip_filename}" \
    --compatible-runtimes "${compatible_runtimes[@]}" \
    --compatible-architectures "${compatible_architectures[@]}"

if [[ $? -eq 0 ]]; then
  echo ""
  echo -e " -> ${ok_bar}"
  echo -e "    Updated AWS Lambda Layer '${c_y}${lambda_layer_name}${d_off}'."
else
  echo ""
  echo -e " -> ${ng_bar}"
  echo -e "    Updating AWS Lambda Layer '${c_y}${lambda_layer_name}${d_off}' failed."

  abort_this_script
fi

# 5. Clean up ./${zip_filename}, ./${rubygems_build_dirname}/, and ./.bundle/

echo_title "[5/5] Clean up ${c_y}./${zip_filename}${d_off}${f_b}${f_u}, ${c_y}./${rubygems_build_dirname}/${d_off}${f_b}${f_u}, and ${c_y}./.bundle/${d_off}${f_b}${f_u}."

rm ./"${zip_filename}"
echo -e "    * Deleted existing ${c_y}./${zip_filename}${d_off}."

rm -rf ./"${rubygems_build_dirname}"/
echo -e "    * Deleted existing ${c_y}./${rubygems_build_dirname}/${d_off}."

rm -rf ./.bundle/
echo -e "    * Deleted existing ${c_y}./.bundle/${d_off}."

echo ""
echo -e " -> ${ok_bar}"

# Completed!

echo ""
echo "Completed!"
exit 0
