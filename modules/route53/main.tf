data "aws_route53_zone" "zone" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "a" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alias_name
    zone_id                = var.alias_zone_id
    evaluate_target_health = true
  }
}