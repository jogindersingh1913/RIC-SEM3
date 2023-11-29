FROM ubuntu:latest
USER root
#RUN mkdir -p /proc/1/ns/mnt/host

RUN apt-get update && apt-get install -y procps

#RUN chroot /proc/1/ns/mnt/host

CMD ["bash"]
