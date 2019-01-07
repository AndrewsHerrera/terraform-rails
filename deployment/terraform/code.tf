provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr_block}"

  tags {
    Name = "${var.project_name}-${var.environment}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = "${length(var.public_subnets)}"
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${var.public_subnets[count.index]}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.project_name}-${var.environment}-public"
  }
}

resource "aws_subnet" "private" {
  count             = "${length(var.private_subnets)}"
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${var.private_subnets[count.index]}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags {
    Name = "${var.project_name}-${var.environment}-private"
  }
}

resource "aws_security_group" "ssh" {
  name   = "${var.project_name}-${var.environment}-SSH"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.environment}-SSH"
  }
}

resource "aws_security_group" "http" {
  name   = "${var.project_name}-${var.environment}-HTTP"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.environment}-HTTP"
  }
}

resource "aws_security_group" "https" {
  name   = "${var.project_name}-${var.environment}-HTTPS"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.environment}-HTTPS"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = ["${aws_subnet.private.*.id}"]
}

resource "aws_db_parameter_group" "parameter_group" {
  name      = "${var.project_name}-${var.environment}"
  family    = "${var.family}"
  parameter = "${var.parameters}"
}

resource "aws_security_group" "internal" {
  name   = "${var.project_name}-${var.environment}-internal"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.environment}-internal"
  }
}

resource "aws_db_instance" "db" {
  identifier                = "${var.project_name}-${var.environment}"
  allocated_storage         = "${var.allocated_storage}"
  storage_type              = "${var.storage_type}"
  engine                    = "${var.engine}"
  engine_version            = "${var.engine_version}"
  instance_class            = "${var.instance_class}"
  name                      = "${replace(var.project_name, "-", "_")}_${var.environment}"
  username                  = "${replace(var.project_name, "-", "_")}"
  password                  = "${var.rds_password}"
  parameter_group_name      = "${aws_db_parameter_group.parameter_group.id}"
  db_subnet_group_name      = "${aws_db_subnet_group.db_subnet_group.id}"
  final_snapshot_identifier = "${var.project_name}-${var.environment}-${var.date}"
  backup_retention_period   = "${var.backup_retention_days}"
  copy_tags_to_snapshot     = "${var.copy_tags_to_snapshot}"
  vpc_security_group_ids    = ["${aws_security_group.internal.id}"]
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "${var.project_name}-${var.environment}"

  retention_in_days = "${var.retention_in_days}"

  tags = {
    Environment = "${var.environment}"
    Application = "${var.project_name}"
  }
}

resource "aws_ecr_repository" "ecr_repository" {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_ecr_repository_policy" "ecr_repository_policy" {
  repository = "${aws_ecr_repository.ecr_repository.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CodeBuildAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
EOF
}

data "template_file" "task_definition_json" {
  template = "${file("./files/task_definition.json")}"

  vars {
    container_memory_limit = "${var.container_memory_limit}"
    container_name         = "${var.project_name}"
    docker_image           = "${aws_ecr_repository.ecr_repository.repository_url}:${var.docker_image}"
    aws_secret_group       = "${aws_secretsmanager_secret.secrets_manager.name}"
    aws_region             = "${var.region}"
    aws_access_key_id      = "${aws_iam_access_key.secrets.id}"
    aws_secret_access_key  = "${aws_iam_access_key.secrets.secret}"
    application_port       = "${var.application_port}"
    project_name           = "${var.project_name}"
    environment            = "${var.environment}"
    region                 = "${var.region}"
  }
}

resource "aws_ecs_task_definition" "task_definition" {
  family                = "${var.project_name}-${var.environment}"
  container_definitions = "${data.template_file.task_definition_json.rendered}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-${var.environment}"
}

data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

data "template_file" "user_data" {
  template = "${file("./files/user-data.sh")}"

  vars {
    ecs_cluster_name = "${var.project_name}-${var.environment}"
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.ssh_public_key}"
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-${var.environment}-ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-instance-role"
  }
}

resource "aws_iam_policy_attachment" "ecs_instance_policy_attachment" {
  name       = "${var.project_name}-${var.environment}-ecs-instance-policy-attachment"
  roles      = ["${aws_iam_role.ecs_instance_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-${var.environment}-ecs-instance-profile"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_launch_configuration" "launch_configuration" {
  name                 = "${var.project_name}-${var.environment}-${var.date}"
  image_id             = "${data.aws_ami.ecs_ami.id}"
  instance_type        = "${var.ec2_instance_type}"
  user_data            = "${data.template_file.user_data.rendered}"
  key_name             = "${var.key_pair_name}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs_instance_profile.name}"
  enable_monitoring    = "${var.enable_monitoring}"
  security_groups      = ["${aws_security_group.internal.id}", "${aws_security_group.ssh.id}", "${aws_security_group.http.id}", "${aws_security_group.https.id}"]

  root_block_device {
    volume_type = "${var.volume_type}"
    volume_size = "${var.volume_size}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = "${var.project_name}-${var.environment}"
  launch_configuration      = "${aws_launch_configuration.launch_configuration.id}"
  vpc_zone_identifier       = ["${aws_subnet.public.*.id}"]
  min_size                  = "${var.min_size}"
  max_size                  = "${var.max_size}"
  desired_capacity          = "${var.desired_capacity}"
  health_check_grace_period = "${var.health_check_grace_period}"

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

resource "aws_route_table_association" "route_table_association" {
  count          = "${length(var.public_subnets)}"
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.route_table.id}"
}

resource "aws_lb" "public_lb" {
  name               = "${var.project_name}-${var.environment}"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.http.id}", "${aws_security_group.https.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]

  tags {
    Name = "${var.project_name}-${var.environment}"
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "${var.project_name}-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"

  health_check {
    path                = "${var.target_group_path}"
    matcher             = "${var.target_group_status}"
    timeout             = "${var.target_group_timeout}"
    interval            = "${var.target_group_interval}"
    healthy_threshold   = "${var.target_group_healthy}"
    unhealthy_threshold = "${var.target_group_unhealthy}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.public_lb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

data "aws_route53_zone" "selected" {
  name = "${var.route53_domain}."
}

resource "aws_route53_record" "route53_record" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "${var.environment == "production" ? data.aws_route53_zone.selected.name : "${var.environment}.${data.aws_route53_zone.selected.name}" }"
  type    = "A"

  alias {
    name                   = "${aws_lb.public_lb.dns_name}"
    zone_id                = "${aws_lb.public_lb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "ssl" {
  domain_name               = "${var.route53_domain}"
  subject_alternative_names = ["*.${var.route53_domain}"]
  validation_method         = "DNS"

  tags {
    Name = "${var.project_name}-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.public_lb.arn}"
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_acm_certificate.ssl.arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = "${aws_lb_listener.http.arn}"

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    field  = "host-header"
    values = ["${var.environment == "production" ? var.route53_domain : "${var.environment}.${var.route53_domain}" }"]
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  count       = "${var.redis? 1 : 0 }"
  name        = "${var.project_name}-${var.environment}"
  subnet_ids  = ["${aws_subnet.private.*.id}"]
}

resource "aws_elasticache_parameter_group" "redis" {
  count       = "${var.redis? 1 : 0 }"
  name        = "${var.project_name}-${var.environment}"
  family      = "${var.aws_elasticache_parameter_group_redis_family}"
  parameter   = ["${var.aws_elasticache_parameter_group_redis_parameter}"]
}

resource "aws_elasticache_cluster" "redis" {
  count                = "${var.redis? 1 : 0 }"
  cluster_id           = "${substr("${var.project_name}-${var.environment}", 0, 20)}"
  engine               = "${var.elasticache_cluster_redis_engine}"
  engine_version       = "${var.elasticache_cluster_redis_engine_version}"
  node_type            = "${var.elasticache_cluster_redis_node_type}"
  num_cache_nodes      = "${var.elasticache_cluster_redis_num_cache_nodes}"
  security_group_ids   = ["${aws_security_group.internal.id}"]
  subnet_group_name    = "${aws_elasticache_subnet_group.redis.name}"
  parameter_group_name = "${aws_elasticache_parameter_group.redis.id}"

  tags {
    Name  = "${var.project_name}-${var.environment}"
  }
}

resource "aws_secretsmanager_secret" "secrets_manager" {
  name = "${var.project_name}-${var.environment}"

  tags {
    Name = "${var.project_name}-${var.environment}"
  }
}

data "template_file" "secrets" {
  template = "${file("./files/secrets.json")}"

  vars {
    secret_key_base = "${var.secret_key_base}"
    database_url    = "postgres://${aws_db_instance.db.username}:${var.rds_password}@${aws_db_instance.db.endpoint}/${aws_db_instance.db.name}"
    redis_url = "${var.redis? "redis://${aws_elasticache_cluster.redis.cache_nodes.0.address}:6379/0" : "" }"
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = "${aws_secretsmanager_secret.secrets_manager.id}"
  secret_string = "${data.template_file.secrets.rendered}"

  lifecycle {
    ignore_changes = ["secret_string"]
  }
}

resource "aws_iam_user" "secrets" {
  name = "${var.project_name}-${var.environment}-secrets-manager"
}

resource "aws_iam_access_key" "secrets" {
  user = "${aws_iam_user.secrets.name}"
}

data "template_file" "secrets_policy" {
  template = "${file("./files/secrets_policy.json")}"

  vars {
    arn = "${aws_secretsmanager_secret.secrets_manager.arn}"
  }
}

resource "aws_iam_user_policy" "secrets" {
  name   = "${var.project_name}-${var.environment}-secrets-manager"
  user   = "${aws_iam_user.secrets.name}"
  policy = "${data.template_file.secrets_policy.rendered}"
}

resource "aws_iam_role" "ecs_service_role" {
  name = "${var.project_name}-${var.environment}-ecs-service-role"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-service-role"
  }
}

resource "aws_iam_policy_attachment" "ecs_service_policy_attachment" {
  name       = "${var.project_name}-${var.environment}-ecs-service-policy-attachment"
  roles      = ["${aws_iam_role.ecs_service_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_ecs_service" "ecs_service" {
  name                               = "${var.project_name}-${var.environment}"
  cluster                            = "${aws_ecs_cluster.cluster.id}"
  task_definition                    = "${aws_ecs_task_definition.task_definition.arn}"
  desired_count                      = "${var.desired_count}"
  iam_role                           = "${aws_iam_role.ecs_service_role.name}"
  health_check_grace_period_seconds  = "${var.health_check_grace_period_seconds}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  depends_on                         = ["aws_lb_listener_rule.redirect_http_to_https", "aws_iam_user_policy.secrets"]

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
    container_name   = "${var.project_name}"
    container_port   = "${var.application_port}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
