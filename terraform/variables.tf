variable "region" {
  description = "OCI region to deploy into. Use an India region for an India-origin VPN."
  type        = string
  default     = "ap-mumbai-1" # alternative: ap-hyderabad-1
}

variable "compartment_id" {
  description = "OCID of the compartment to create resources in (your tenancy root OCID works for a personal account)."
  type        = string
}

variable "ssh_public_key" {
  description = "Your local SSH public key contents (e.g. `cat ~/.ssh/id_ed25519.pub`), installed on the instance for the 'opc' user."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the instance. Default is nobody; override with YOUR_IP/32 before applying."
  type        = string
  default     = "127.0.0.1/32"
}

variable "instance_shape" {
  description = "Always Free compute shape. VM.Standard.A1.Flex (ARM) is preferred; fall back to VM.Standard.E2.1.Micro (AMD) if ARM capacity is unavailable in your region."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs for the Flex shape (ignored for E2.1.Micro). Always Free allows up to 4 total across all A1.Flex instances."
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memory in GB for the Flex shape (ignored for E2.1.Micro). Always Free allows up to 24GB total across all A1.Flex instances."
  type        = number
  default     = 6
}

variable "wireguard_port" {
  description = "UDP port WireGuard listens on."
  type        = number
  default     = 51820
}
