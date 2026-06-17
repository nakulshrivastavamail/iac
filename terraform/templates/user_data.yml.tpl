#cloud-config
hostname: ${hostname}
manage_etc_hosts: true
ssh_pwauth: true

users:
  - name: kube
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab
  - modprobe br_netfilter
  - modprobe overlay
  - echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
  - echo "overlay" >> /etc/modules-load.d/k8s.conf
  - echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.d/k8s.conf
  - echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.d/k8s.conf
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/k8s.conf
  - sysctl --system