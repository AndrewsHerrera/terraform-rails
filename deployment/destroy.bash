#!/bin/bash
if [ -n "$TF_VAR_region" ] && [ -n "$TF_VAR_route53_domain" ]
then
  s3_remote_state=$(ls terraform | grep s3_remote_state.tf.$TF_VAR_environment)
  use_remote_state=$(ls terraform | grep use_remote_state.tf.$TF_VAR_environment)
  if [ -n "$s3_remote_state" ] && [ -n "$use_remote_state" ]
  then
    cat terraform/$s3_remote_state > terraform/s3_remote_state.tf
    cat terraform/$use_remote_state > terraform/use_remote_state.tf
  fi
  export TF_VAR_project_name="whatever"
  export TF_VAR_environment="whatever"
  export TF_VAR_rds_password="whatever"
  export TF_VAR_date="whatever"
  export TF_VAR_secret_key_base="whatever"
  export TF_VAR_key_pair_name="whatever"
  export TF_VAR_ssh_public_key="whatever"
  rm -rf terraform/terraform.* terraform/.terraform
  cd terraform
  terraform init
  terraform state pull > terraform.tfstate
  cd ..
  rm -rf terraform/use_remote_state.tf terraform/.terraform
  cd terraform
  terraform init
  arn_certificate=$(terraform output arn_certificate)
  hosted_zone_id=$(terraform output hosted_zone_id)
  cd ..
  record_name=$(aws acm describe-certificate --certificate-arn $arn_certificate | grep '"Name": ' | head -n 1 | cut -d '"' -f 4)
  acm_record=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id | grep $record_name)
  if [ -n "$acm_record" ]
  then
    record_value=$(aws acm describe-certificate --certificate-arn $arn_certificate | grep '"Value": ' | head -n 1 | cut -d '"' -f 4)
    cat templates/route53_certificate_record.json.template | \
    sed "s/{{action}}/DELETE/" | \
    sed "s/{{name}}/$record_name/" | \
    sed "s/{{value}}/$record_value/" \
    > route53_certificate_record.json
    aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file://route53_certificate_record.json
    rm -rf route53_certificate_record.json
  fi
  set -eu
  cat terraform/s3_remote_state.tf | sed "s/false/true/" > terraform/s3_remote_state.tmp.tf
  mv terraform/s3_remote_state.tmp.tf terraform/s3_remote_state.tf
  cd terraform
  touch s3_remote_state.tfstate
  terraform state mv -state-out=s3_remote_state.tfstate aws_s3_bucket.remote_state aws_s3_bucket.remote_state
  terraform destroy --auto-approve
  terraform state mv -state=s3_remote_state.tfstate -state-out=terraform.tfstate aws_s3_bucket.remote_state aws_s3_bucket.remote_state
  terraform apply -target="aws_s3_bucket.remote_state" --auto-approve
  terraform destroy --auto-approve
  cd ..
  rm -rf terraform/s3_remote_state.tfstate terraform/use_remote_state.tf terraform/s3_remote_state.tf terraform/.terraform terraform/terraform.*
else
  echo "You have to export these variables"
  echo "export TF_VAR_region=$TF_VAR_region"
  echo "export TF_VAR_route53_domain=$TF_VAR_route53_domain"
fi
