FROM ubuntu:trusty
MAINTAINER ek <417@xmlad.com>

ENV DEBIAN_FRONTEND noninteractive
ENV GITHUB_OAUTH 4d4c11b03f79723c0b5cc3eecfd8caa5252e8f90
ENV HOME /root
RUN apt-mark hold initscripts udev plymouth mountall
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

RUN apt-get update \
    && apt-get install -y --force-yes --no-install-recommends \
        openssh-server sudo vim \
        net-tools \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/bin/python3 /usr/bin/python
ADD run.sh /
ADD install.sh /
RUN chmod 755 /run.sh
RUN chmod 755 /install.sh
EXPOSE 80
EXPOSE 22
WORKDIR /
ENTRYPOINT ["/run.sh"]
RUN /run.sh