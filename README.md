# Terraform Rails

### Description
Terraform-Rails is a project that uses several scripts to do everything you need to have your rails application in AWS with good security configurations

### Requirements

- AWS CLI
- Terraform
- Docker
- IAM user with AdministratorAccess
- Hosted zone created in Route53

### create.bash
This is the main file. It has all the deployment instructions and is in charge to do the most important things such as creating new files based on templates, modify the database.yml, run the Terraform Scripts, validate the ACM certificate and some more

### destroy.bash
It used to delete the current AWS infrastructure which was created by create.bash

### How to use it

Enter your console, go to your applications folder and clone this repository
```
cd ~/Documents
git clone git@github.com:koombea/terraform-rails.git
```

Now that you have terraform-rails locally, go to the application folder that you want to deploy
```
cd ~/Documents/my_rails_application
```
Copy the deployment folder to your rails application like this
```
cp -r ~/Documents/terraform-rails/deployment ~/Documents/my_rails_application/
```
If you need to use redis then do this, its default value is false
```
export TF_VAR_redis=true
```
The AWS resource names will have project_name-environment added so if you want to have a better nomenclature don't put the environment name in TF_VAR_project_name value. If you use the name production as the TF_VAR_environment value, you will have the application running in your naked domain otherwise you will have it like this... staging.mydomain.com <TF_VAR_environment>.<TF_VAR_route53_domain>. The next are the required variables
```
export AWS_PROFILE=
export TF_VAR_project_name=
export TF_VAR_environment=
export TF_VAR_rds_password=
export TF_VAR_route53_domain=
export TF_VAR_region=
```
Finally you are ready to run the main script which is create.bash.
If for some reason you have not exported the required environment variables, the script will ask you for them before starting creating things
```
bash create.bash
```
