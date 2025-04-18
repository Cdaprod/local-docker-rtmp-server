docker network create -d macvlan \
  --subnet=192.168.0.0/24 \
  --gateway=192.168.0.1 \
  --ip-range=192.168.0.200/29 \
  -o parent=eth0 \
  obs_macvlan