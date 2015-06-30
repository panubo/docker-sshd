FROM alpine:latest

MAINTAINER Andrew Cutler <andrew@panubo.com>

RUN apk update && \
  apk add openssh rsync && \
  rm -rf /var/cache/apk/* && \
  mkdir -p ~root/.ssh && chmod 700 ~root/.ssh/ && \
  echo -e "Port 22\n" >> /etc/ssh/sshd_config

EXPOSE 22

COPY entry.sh /entry.sh

ENTRYPOINT ["/entry.sh"]

CMD ["/usr/sbin/sshd", "-D", "-f", "/etc/ssh/sshd_config"]
