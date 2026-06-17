[control_plane]
k8s-control-plane ansible_host=${control_plane_ip}

[workers]
%{ for name, ip in worker_ips ~}
${name} ansible_host=${ip}
%{ endfor ~}

[all:vars]
ansible_user=kube
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'