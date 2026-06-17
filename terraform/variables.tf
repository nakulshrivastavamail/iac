variable "nodes" {
    default = {
        "k8s-control-plane" = {
            ip ="192.168.122.10",
            memory = 4096,
            vcpu = 2,
            disk_gb = 20
        }
        "k8s-worker-1" = {
            ip = "192.168.122.11",
            memory = 2048,
            vcpu = 2,
            disk_gb = 20
        }
        "k8s-worker-2" = {
            ip = "192.168.122.12",
            memory = 2048,
            vcpu = 2,
            disk_gb = 20
        }
    }
}