FROM i386/python:3.10-slim-buster

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && \
  apt --yes --no-install-recommends install \
  linux-image-686 systemd vim systemd-sysv \
  && \
  chsh -s /bin/bash && \
  echo "root:root" | chpasswd && \
  rm /etc/motd /etc/issue && \
  echo "tmpfs /tmp tmpfs nodev,nosuid 0 0" >> /etc/fstab

RUN echo "export TERM=xterm-256color" >> ~/.bashrc

COPY networking.sh /root/

RUN mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d/ && \
  systemctl enable serial-getty@ttyS0.service && \
  rm /lib/systemd/system/getty.target.wants/getty-static.service && \
  systemctl disable systemd-timesyncd.service && \
  systemctl disable apt-daily.timer && \
  systemctl disable apt-daily-upgrade.timer && \
  systemctl disable dhcpcd.service

COPY getty-noclear.conf getty-override.conf /etc/systemd/system/getty@tty1.service.d/
COPY getty-autologin-serial.conf /etc/systemd/system/serial-getty@ttyS0.service.d/

COPY logind.conf /etc/systemd/logind.conf

RUN printf '%s\n' 9p 9pnet 9pnet_virtio virtio virtio_ring virtio_pci | tee -a /etc/initramfs-tools/modules && \
  update-initramfs -u

RUN apt-get --yes clean && \
  rm -r /var/lib/apt/lists/* && \
  rm -r /usr/share/doc/* && \
  rm -r /usr/share/man/* && \
  rm /var/log/*.log /var/log/lastlog /var/log/wtmp /var/log/apt/*.log /var/log/apt/*.xz
