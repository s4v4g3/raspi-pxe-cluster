ARG OS_VARIANT=armhf
ARG RASPI_SN=5150947b
ARG HOST_IP=10.4.1.166


FROM ubuntu:20.04 as builder-base
WORKDIR /work
RUN apt update && apt install -y wget kpartx unzip xz-utils
RUN wget -O 7z.tar.xz https://7-zip.org/a/7z2101-linux-x64.tar.xz
RUN tar xvf 7z.tar.xz

#FROM ubuntu:20.04 as base
#RUN apt update && apt install -y unzip kpartx dnsmasq nfs-kernel-server wget


FROM builder-base as raspios-arm64
ARG IMAGE_URL_ARM64=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-04-09/2021-03-04-raspios-buster-arm64-lite.zip
ENV IMAGE_URL=${IMAGE_URL_ARM64}
RUN echo image url is ${IMAGE_URL}

FROM builder-base as raspios-armhf
ARG IMAGE_URL_ARMHF=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip
ENV IMAGE_URL=${IMAGE_URL_ARMHF}
RUN echo image url is ${IMAGE_URL}

FROM raspios-${OS_VARIANT} as builder
RUN wget -O raspios.zip --quiet ${IMAGE_URL} && unzip raspios.zip && mv *.img raspios.img && rm -rf raspios.zip
RUN ./7zz x raspios.img
#RUN ./7zz x -oboot ./0.fat

RUN mkdir /p output
COPY extract_image.sh .
RUN chmod +x extract_image.sh

CMD ./extract_image.sh







