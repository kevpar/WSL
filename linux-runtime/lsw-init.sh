mkdir /var/lib/containerd
mount -t tmpfs tmpfs /var/lib/containerd

mount -t cgroup2 cgroup2 /sys/fs/cgroup

PATH=/bin containerd >/var/log/containerd 2>&1 &