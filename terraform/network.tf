resource "oci_core_vcn" "vpn_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "vpntunnel-vcn"
  dns_label      = "vpntunnel"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpntunnel-igw"
  enabled        = true
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpntunnel-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vpn_vcn.id
  display_name   = "vpntunnel-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # WireGuard: open to the world, clients connect from anywhere.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17" # UDP
    udp_options {
      min = var.wireguard_port
      max = var.wireguard_port
    }
  }

  # SSH: restricted to admin_cidr only.
  ingress_security_rules {
    source   = var.admin_cidr
    protocol = "6" # TCP
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow ICMP for path MTU discovery.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1" # ICMP
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.vpn_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "vpntunnel-subnet"
  dns_label                  = "vpnsubnet"
  route_table_id             = oci_core_route_table.rt.id
  security_list_ids          = [oci_core_security_list.sl.id]
  prohibit_public_ip_on_vnic = false
}
