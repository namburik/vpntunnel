# vpntunnel — free WireGuard VPN with an India exit

A personal WireGuard VPN hosted on Oracle Cloud's **Always Free** tier in
Mumbai/Hyderabad, so your traffic egresses from India. Full-tunnel by
default (`AllowedIPs = 0.0.0.0/0`) — once connected, all your traffic routes
through the India server.

## 1. One-time manual setup (cannot be automated)

1. Create an OCI account: https://signup.oraclecloud.com (requires a credit
   card for identity verification; Always Free resources are never billed).
2. Install the OCI CLI and run `oci setup config` — this writes
   `~/.oci/config` and an API key pair that Terraform will use. Note your
   **tenancy OCID** (shown during setup, or in Profile → Tenancy).
3. Install Terraform (`brew install terraform`) and the WireGuard tools on
   your Mac (`brew install wireguard-tools qrencode`).

## 2. Provision the server

```sh
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set compartment_id, ssh_public_key, admin_cidr
# (admin_cidr = your current IP, e.g. "$(curl -s ifconfig.co)/32")

terraform init
terraform apply
```

**If you hit `Out of host capacity`** for `VM.Standard.A1.Flex` (common —
Oracle's free ARM capacity in India regions is often exhausted): set
`instance_shape = "VM.Standard.E2.1.Micro"` in `terraform.tfvars` and
re-apply. It's a smaller AMD box but plenty for a single-user WireGuard
relay.

`terraform apply` prints `public_ip` and an `ssh_command`. Cloud-init runs
`setup-wireguard.sh` automatically on first boot — give it ~1-2 minutes,
then verify:

```sh
ssh opc@<public_ip> sudo wg show
```

## 3. Add a device

Each device (this Mac, your phone) needs its own peer:

```sh
ssh opc@<public_ip> 'sudo /root/add-client.sh macbook'
```

This prints the client config, a terminal QR code, and saves both under
`/root/clients/` on the server.

- **Phone**: open the WireGuard app, "Add tunnel" → "Scan from QR code",
  scan the terminal output (or `scp` the `.png` over and open it).
- **Mac**: copy the config down and connect:

```sh
scp opc@<public_ip>:/root/clients/macbook.conf client/macos/macbook.conf
./client/macos/connect.sh client/macos/macbook.conf
./client/macos/status.sh      # should show a handshake + country = IN
./client/macos/disconnect.sh  # when done
```

Repeat `add-client.sh <name>` for each additional device — it hot-reloads
the server without dropping existing connections.

## Notes / gotchas

- **Firewall**: the OCI security list opens UDP 51820, but Oracle Linux's
  own `firewalld` also blocks it by default — `setup-wireguard.sh` opens
  both. If WireGuard won't connect, check `sudo firewall-cmd --list-ports`
  on the server.
- **Full tunnel**: `AllowedIPs = 0.0.0.0/0` sends *all* client traffic
  through India, including DNS (set to `1.1.1.1` by default). Change
  `AllowedIPs` in `add-client.sh` if you only want specific subnets routed.
- **Cost**: everything here fits inside Oracle's Always Free limits (1
  A1.Flex OCPU/6GB, or 1 E2.1.Micro, one block-volume boot disk, outbound
  data allowance). Oracle may reclaim an Always Free instance that's
  idle/unreachable for an extended period — keep it in light use.
- **Secrets**: `terraform.tfvars`, `*.tfstate`, and all generated `.conf`/
  `.png` files are gitignored. Don't commit them.
