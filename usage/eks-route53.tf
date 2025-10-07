module "prometheus_a" {
  source        = "../../modules/route53-alias-a"
  zone_name     = "gal-rozman.com"
  record_name   = "prometheus"
  alias_name    = aws_lb.my_alb.dns_name
  alias_zone_id = aws_lb.my_alb.zone_id
}