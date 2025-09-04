#Exports the certificate for the ec2 module to use do sploy on lb

#create a new certificate, i have an existing one
data "aws_acm_certificate" "awaiswpcert" {
    domain = "awais-wp.groveops.net"
    statuses = ["ISSUED"]
    most_recent = true
}

#Get the hosted zone to create the record in. (can create a new one too)
data "aws_route53_zone" "recordzone" {
  name         = "groveops.net"
  private_zone = false
  
}

#Create a record in the hosted zone and attach it to load balancer DNS
resource "aws_route53_record" "awaiswprecord" {
  zone_id = data.aws_route53_zone.recordzone.id #hosted zone id
  name = "awais-wp.groveops.net"  #record name
  type = "A"

  alias {   #alias to specify where to route the traffic
    name = var.lb_dns   #lb dns name
    zone_id = var.lb_zone   #lb dns id
    evaluate_target_health = true
  }
}