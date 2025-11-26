ARG envtype=prod

FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build

RUN tdnf install --releasever=3.0 --installroot=/rootfs -y \
    ca-certificates \
    containerd2 \
    containernetworking-plugins \
    runc \
    e2fsprogs \
    busybox \
    iptables

RUN tdnf clean --releasever=3.0 --installroot=/rootfs all

RUN tdnf install -y \
    ca-certificates \
    golang \
    git \
    build-essential

RUN git clone --branch v2.2.0 --depth 1 https://github.com/containerd/nerdctl.git /src/nerdctl
WORKDIR /src/nerdctl
RUN CGO_ENABLED=1 go build -o /rootfs/bin/nerdctl ./cmd/nerdctl


FROM scratch AS rootfs_prod

COPY --from=build /rootfs /


FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS rootfs_debug

RUN tdnf install -y \
    ca-certificates \
    containerd2 \
    containernetworking-plugins \
    runc \
    e2fsprogs \
    busybox \
    iptables \
    tdnf


FROM rootfs_${envtype} AS rootfs

RUN /sbin/busybox --install -s


FROM build AS vhd

RUN --mount=type=bind,from=rootfs,target=/rootfs \
    tar -cf /rootfs.tar -C /rootfs .

RUN go run github.com/Microsoft/hcsshim/cmd/tar2ext4@v0.13.0 -vhd -i /rootfs.tar -o /rootfs.vhd


FROM scratch

COPY --from=vhd /rootfs.vhd /