version: 2
ethernets:
  id0:
    match:
      name: "en*"
    dhcp4: false
    addresses:
      - ${ip_address}/24
    routes:
      - to: default
        via: 192.168.122.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4