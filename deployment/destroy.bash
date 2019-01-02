#!/bin/bash
if [ -n "$TF_VAR_region" ] && [ -n "$TF_VAR_route53_domain" ]
then
  export TF_VAR_project_name="whatever"
  export TF_VAR_environment="whatever"
  export TF_VAR_rds_password="whatever"
  export TF_VAR_date="whatever"
  export TF_VAR_secret_key_base="whatever"
  export TF_VAR_key_pair_name="whatever"
  export TF_VAR_ssh_public_key="whatever"
  rm -rf terraform/remote_state.tmp.tf
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
  cat terraform/remote_state.tf | sed "s/false/true/" > terraform/remote_state.tmp.tf
  mv terraform/remote_state.tf remote_state.tf.tmp
  cd terraform
  terraform apply -target="aws_s3_bucket.remote_state" --auto-approve
  terraform destroy -target="aws_db_instance.db" --auto-approve
  terraform destroy --auto-approve
  cd ..
  mv remote_state.tf.tmp terraform/remote_state.tf
  rm -rf terraform/remote_state.tmp.tf terraform/.terraform terraform/terraform.*
else
  echo "You have to export these variables"
  echo "export TF_VAR_region=$TF_VAR_region"
  echo "export TF_VAR_route53_domain=$TF_VAR_route53_domain"
fi
