data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  is_flex_shape = can(regex("Flex$", var.instance_shape))
}

resource "oci_core_instance" "vpn_server" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "vpntunnel-india"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flex_shape ? [1] : []
    content {
      ocpus         = var.instance_ocpus
      memory_in_gbs = var.instance_memory_gb
    }
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  # Default ISCSI boot-volume attachment can hang early boot on this
  # shape/image/region combo ("iscsiadm: Cannot resolve host iscsi").
  # Paravirtualized attachment avoids that boot-time iSCSI negotiation.
  launch_options {
    boot_volume_type = "PARAVIRTUALIZED"
    network_type     = "PARAVIRTUALIZED"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      setup_script      = file("${path.module}/../server/setup-wireguard.sh")
      add_client_script = file("${path.module}/../server/add-client.sh")
      wg_port           = var.wireguard_port
    }))
  }
}
