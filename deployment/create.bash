#!/bin/bash
if [ -n "$AWS_PROFILE" ] && [ -n "$TF_VAR_project_name" ] && [ -n "$TF_VAR_environment" ] && [ -n "$TF_VAR_rds_password" ] && [ -n "$TF_VAR_route53_domain" ] && [ -n "$TF_VAR_region" ]
then
  s3_remote_state=$(ls terraform | grep s3_remote_state.tf.$TF_VAR_environment)
  use_remote_state=$(ls terraform | grep use_remote_state.tf.$TF_VAR_environment)
  if [ -n "$s3_remote_state" ] && [ -n "$use_remote_state" ]
  then
    cat terraform/$s3_remote_state > terraform/s3_remote_state.tf
    cat terraform/$use_remote_state > terraform/use_remote_state.tf
  fi
  mv ../config/database.yml ../config/database.yml.tmp
  cat templates/database.yml.template | \
  sed "s/{{project_name}}/$TF_VAR_project_name/" \
  > ../config/database.yml
  project_ruby_version=$(cat ../Gemfile | grep "ruby '" | cut -d "'" -f 2)
  cat templates/Dockerfile.template | \
  sed "s/{{project_ruby_version}}/$project_ruby_version/" \
  > ../Dockerfile
  cp templates/entrypoint.template ../bin/entrypoint
  chmod 700 ../bin/entrypoint
  okcomputer=$(cat ../Gemfile | grep "gem 'okcomputer'")
  if [ -z "$okcomputer" ]
  then
    printf "\n# Health checks using okcomputer\ngem 'okcomputer', '~> 1.17.3'" >> ../Gemfile
  fi
  silencer=$(cat ../Gemfile | grep "gem 'silencer'")
  if [ -z "$silencer" ]
  then
    printf "\n# Remove health checks from the logs\ngem 'silencer', '~> 1.0.1'" >> ../Gemfile
    cp templates/silencer.rb.template ../config/initializers/silencer.rb
  fi
  secretsmanager=$(cat ../Gemfile | grep "gem 'aws-sdk-secretsmanager'")
  if [ -z "$secretsmanager" ]
  then
    printf "\n# Connect to aws secret manager\ngem 'aws-sdk-secretsmanager'" >> ../Gemfile
    cp templates/aws_secrets.rb.template ../config/initializers/aws_secrets.rb
  fi
  if [ "$TF_VAR_environment" != "production" ]
  then
    cp ../config/environments/production.rb ../config/environments/$TF_VAR_environment.rb
  fi
  rm -rf ../tmp terraform/.terraform
  docker build -t $TF_VAR_project_name ../
  mv ../config/database.yml.tmp ../config/database.yml
  export TF_VAR_date=$(date +%F-%s)
  export TF_VAR_secret_key_base=$(docker run -e RUN_MIGRATIONS=false $TF_VAR_project_name':latest' rake secret)
  export TF_VAR_key_pair_name=$(cat ~/.ssh/id_rsa.pub | head -n 1 | awk '{ print $3 }')"($TF_VAR_project_name-$TF_VAR_environment)"
  export TF_VAR_ssh_public_key=$(cat ~/.ssh/id_rsa.pub | head -n 1)
  cd terraform
  terraform init
  terraform apply -target="aws_acm_certificate.ssl" --auto-approve
  arn_certificate=$(terraform output arn_certificate)
  terraform apply -target="data.aws_route53_zone.selected" --auto-approve
  hosted_zone_id=$(terraform output hosted_zone_id)
  cd ..
  record_name=$(aws acm describe-certificate --certificate-arn $arn_certificate | grep '"Name": ' | head -n 1 | cut -d '"' -f 4)
  record_value=$(aws acm describe-certificate --certificate-arn $arn_certificate | grep '"Value": ' | head -n 1 | cut -d '"' -f 4)
  acm_record=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id | grep $record_name)
  if [ -z "$acm_record" ]
  then
    cat templates/route53_certificate_record.json.template | \
    sed "s/{{action}}/CREATE/" | \
    sed "s/{{name}}/$record_name/" | \
    sed "s/{{value}}/$record_value/" \
    > route53_certificate_record.json
    aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file://route53_certificate_record.json
    rm -rf route53_certificate_record.json
  fi
  set -eu
  cat templates/remote_state.tf.template | \
  sed "s/{{project_name}}/$TF_VAR_project_name/" | \
  sed "s/{{environment}}/$TF_VAR_environment/" | \
  sed "s/{{force_destroy}}/false/" \
  > terraform/s3_remote_state.tf
  cd terraform
  terraform apply -target="aws_db_instance.db" --auto-approve
  terraform apply --auto-approve
  ecr_repository_url=$(terraform output ecr_repository_url)
  cd ..
  cat templates/use_remote_state.tf.template | \
  sed "s/{{project_name}}/$TF_VAR_project_name/" | \
  sed "s/{{environment}}/$TF_VAR_environment/" | \
  sed "s/{{region}}/$TF_VAR_region/" \
  > terraform/use_remote_state.tf
  cd terraform
  yes yes | terraform init
  cd ..
  mv terraform/s3_remote_state.tf terraform/s3_remote_state.tf.$TF_VAR_environment
  mv terraform/use_remote_state.tf terraform/use_remote_state.tf.$TF_VAR_environment
  rm -rf terraform/.terraform terraform/terraform.*
  cat templates/buildspec.yml.template | \
  sed "s/{{project_name}}/$TF_VAR_project_name/" | \
  sed "s/{{environment}}/$TF_VAR_environment/" | \
  sed "s/{{route53_domain}}/$TF_VAR_route53_domain/" | \
  sed "s/{{region}}/$TF_VAR_region/" | \
  sed "s/{{ecr_repository_url}}/${ecr_repository_url/com/com\\}/" \
  > ../buildspec_$TF_VAR_environment.yml
  $(aws ecr get-login --no-include-email --region us-east-1)
  docker tag $TF_VAR_project_name':latest' $ecr_repository_url':latest'
  docker push $ecr_repository_url':latest'
else
  echo "You have to export these variables"
  echo "export AWS_PROFILE=$AWS_PROFILE"
  echo "export TF_VAR_project_name=$TF_VAR_project_name"
  echo "export TF_VAR_environment=$TF_VAR_environment"
  echo "export TF_VAR_rds_password=$TF_VAR_rds_password"
  echo "export TF_VAR_route53_domain=$TF_VAR_route53_domain"
  echo "export TF_VAR_region=$TF_VAR_region"
fi
