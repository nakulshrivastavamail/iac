# Storage pool
resource "libvirt_pool" "k8s" {
    name = "k8s-pool"
    type = "dir"

    target = {
        path = "/var/lib/libvirt/k8s-pool"
    }

    create = {
        build = true
        start = true
        autostart = true
    }

    destroy = {
        delete = false
    }
}

# Base Ubuntu volume — downloaded once
resource "libvirt_volume" "ubuntu_base" {
    name = "ubuntu-24.04-base.qcow2"
    pool = libvirt_pool.k8s.name
    
    target = {
        format = {
            type = "qcow2"
        }
    }

    create = {
        content = {
            url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
        }
    }
}

# Per-node OS disk — backed by base image
resource "libvirt_volume" "node_disk" {
    for_each = var.nodes

    name = "${each.key}.qcow2"
    pool = libvirt_pool.k8s.name
    capacity = each.value.disk_gb * 1073741824

    target = {
        format = {
            type = "qcow2"
        }
    }

    backing_store = {
        format = {
            type = "qcow2"
        }
        path = libvirt_volume.ubuntu_base.path
    }
}

# Generate cloud-init ISOs (v0.9.x dropped libvirt_cloudinit_disk)
resource "null_resource" "cloudinit_iso" {
  for_each = var.nodes

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p /tmp/cloudinit/${each.key}

      cat > /tmp/cloudinit/${each.key}/user-data << 'USERDATA'
      ${templatefile("${path.module}/templates/user_data.yml.tpl", {
        hostname   = each.key
        ssh_pubkey = trimspace(file(pathexpand("~/.ssh/id_rsa.pub")))
      })}
      USERDATA

      cat > /tmp/cloudinit/${each.key}/meta-data << METADATA
      instance-id: ${each.key}
      local-hostname: ${each.key}
      METADATA

      cat > /tmp/cloudinit/${each.key}/network-config << NETCONFIG
      ${templatefile("${path.module}/templates/network_config.yml.tpl", {
        ip_address = each.value.ip
      })}
      NETCONFIG

      mkisofs -output /tmp/cloudinit/${each.key}.iso \
        -volid cidata -rational-rock -joliet \
        /tmp/cloudinit/${each.key}/user-data \
        /tmp/cloudinit/${each.key}/meta-data \
        /tmp/cloudinit/${each.key}/network-config
    EOT
  }

  triggers = {
    always = timestamp()
  }
}

# Upload cloud-init ISOs as volumes
resource "libvirt_volume" "cloudinit_iso" {
  for_each = var.nodes

  name   = "${each.key}-cloudinit.iso"
  pool   = libvirt_pool.k8s.name

  create = {
    content = {
      url = "/tmp/cloudinit/${each.key}.iso"
    }
  }

  depends_on = [null_resource.cloudinit_iso]
}

# The VMs
resource "libvirt_domain" "node" {
  for_each = var.nodes

  name        = each.key
  type        = "kvm"
  memory      = each.value.memory
  memory_unit = "MiB"
  vcpu        = each.value.vcpu

  os = {
    type      = "hvm"
    type_arch = "x86_64"
  }

  devices = {
    disks = [
      {
        device = "disk"
        driver = {
            name = "qemu"
            type = "qcow2"
        }
        source = {
          volume = {
            volume = libvirt_volume.node_disk[each.key].name
            pool   = libvirt_pool.k8s.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        driver = {
            name = "qemu"
            type = "raw"
        }
        source = {
          volume = {
            volume = libvirt_volume.cloudinit_iso[each.key].name
            pool   = libvirt_pool.k8s.name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        readonly = true
      }
    ]

    interfaces = [
      {
        type = "network"
        model = {
         type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]
  }
}

resource "null_resource" "start_vms" {
  for_each = var.nodes

  provisioner "local-exec" {
    command = <<-EOT
      virsh -c qemu:///system start ${each.key}
      virsh -c qemu:///system autostart ${each.key}
    EOT
  }

  depends_on = [libvirt_domain.node]
}