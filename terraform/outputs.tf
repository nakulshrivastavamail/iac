resource "local_file" "ansible_inventory" {
    content = templatefile("${path.module}/templates/inventory.ini.tpl", {
        control_plane_ip = var.nodes["k8s-control-plane"].ip
        worker_ips = {
            for name, cfg in var.nodes : name => cfg.ip if name != "k8s-control-plane"
        }
    })
    filename = "${path.module}/../ansible/inventory.ini"
}

output "node_ips" {
    value = { for name, cfg in var.nodes : name => cfg.ip }
}