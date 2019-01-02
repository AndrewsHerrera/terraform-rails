output "ecr_repository_url" {
  value = "${aws_ecr_repository.ecr_repository.repository_url}"
}

output "arn_certificate" {
  value = "${aws_acm_certificate.ssl.arn}"
}

output "hosted_zone_id" {
  value = "${data.aws_route53_zone.selected.id}"
}
