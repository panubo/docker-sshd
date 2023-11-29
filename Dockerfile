FROM alpine:3.18

RUN apk update && \
    apk add --no-cache bash git openssh rsync augeas shadow rssh \
                       bind-tools busybox-extras curl ethtool git \
                       iperf3 iproute2 iputils jq lftp mtr mysql-client \
                       netcat-openbsd net-tools nginx nmap openssh-client openssl \
                       perl-net-telnet postgresql-client procps rsync socat tcpdump tshark wget dhclient && \
    deluser $(getent passwd 33 | cut -d: -f1) && \
    delgroup $(getent group 33 | cut -d: -f1) 2>/dev/null || true && \
    mkdir -p ~root/.ssh /etc/authorized_keys && chmod 700 ~root/.ssh/ && \
    augtool 'set /files/etc/ssh/sshd_config/AuthorizedKeysFile ".ssh/authorized_keys /etc/authorized_keys/%u"' && \
    echo -e "Port 22\n" >> /etc/ssh/sshd_config && \
    cp -a /etc/ssh /etc/ssh.cache && \
    rm -rf /var/cache/apk/*

EXPOSE 22

COPY entry.sh /entry.sh

ENTRYPOINT ["/entry.sh"]

CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/ssh/sshd_config"]
