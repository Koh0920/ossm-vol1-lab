FROM ubuntu:24.04@sha256:52df9b1ee71626e0088f7d400d5c6b5f7bb916f8f0c82b474289a4ece6cf3faf

ARG TARGETARCH
ARG UBUNTU_SNAPSHOT=20260714T000000Z
ARG OPENEDA_COMMIT=0259d6e37202eb6bc6f5053891698f24de12b07d
ARG OPENRULE_COMMIT=7b3c4c4d8feca8e94388bb856a42ee4caf8f8763
ARG ANAGIX_COMMIT=cb89e35f742e863dde64c7b047e7f369cb1bce0a

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    HOME=/home/ato \
    DISPLAY=:1 \
    XDG_RUNTIME_DIR=/run/ossm/xdg \
    OSSM_ROOT=/opt/ossm \
    OSSM_WORKSPACE=/foss/designs

RUN test "${TARGETARCH:-amd64}" = "amd64" \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates=20240203 \
    && printf '%s\n' \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} noble main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} noble-updates main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} noble-security main restricted universe multiverse" \
      > /etc/apt/sources.list \
    && rm -f /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates=20260601~24.04.1 \
      git=1:2.43.0-1ubuntu7.3 \
      locales=2.39-0ubuntu8.7 \
      xfce4=4.18 \
      xfce4-terminal=1.1.3-1build1 \
      dbus-x11=1.14.10-4ubuntu4.1 \
      tigervnc-standalone-server=1.13.1+dfsg-2build2 \
      tigervnc-tools=1.13.1+dfsg-2build2 \
      novnc=1:1.3.0-2 \
      websockify=0.10.0+dfsg1-5build2 \
      x11-utils=7.7+6build2 \
      x11-xserver-utils=7.7+10build2 \
      xdotool=1:3.20160805.1-5build1 \
      xdg-utils=1.1.3-4.1ubuntu3 \
      xschem=3.4.4-1 \
      ngspice=42+ds-3build1 \
      klayout=0.28.16-0ubuntu0.24.04.1 \
      netgen-lvs=1.5.133-1.2 \
      python3=3.12.3-0ubuntu2.1 \
      nginx-light=1.24.0-2ubuntu7.13 \
      supervisor=4.2.5-1ubuntu0.1 \
      tini=0.19.0-1 \
      zip=3.0-13ubuntu0.2 \
      unzip=6.0-28ubuntu4.1 \
      fonts-noto-cjk=1:20230817+repack1-3 \
      ristretto=0.13.1-1build2 \
    && locale-gen ja_JP.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN groupmod --new-name ato ubuntu \
    && usermod --login ato --home /home/ato --move-home --comment Ato ubuntu \
    && install -d -o ato -g ato -m 0700 /foss/designs \
    && install -d -o ato -g ato -m 0755 /opt/ossm /run/ossm /run/ossm/xdg \
    && install -d -o ato -g ato -m 0755 /home/ato/Desktop

RUN git init /build/openeda \
    && git -C /build/openeda remote add origin https://github.com/ishi-kai/OpenEDA-PDK_SetupScript.git \
    && git -C /build/openeda fetch --depth=1 origin "${OPENEDA_COMMIT}" \
    && git -C /build/openeda checkout --detach FETCH_HEAD \
    && git init /build/openrule \
    && git -C /build/openrule remote add origin https://github.com/mineda-support/OpenRule1um.git \
    && git -C /build/openrule fetch --depth=1 origin "${OPENRULE_COMMIT}" \
    && git -C /build/openrule checkout --detach FETCH_HEAD \
    && git init /build/anagix \
    && git -C /build/anagix remote add origin https://github.com/mineda-support/AnagixLoader.git \
    && git -C /build/anagix fetch --depth=1 origin "${ANAGIX_COMMIT}" \
    && git -C /build/anagix checkout --detach FETCH_HEAD \
    && cp /build/openeda/LICENSE /opt/ossm/OPENEDA-PDK-SetupScript.LICENSE \
    && cp /build/openrule/LICENSE.txt /opt/ossm/OpenRule1um.LICENSE \
    && cp /build/anagix/LICENSE.txt /opt/ossm/AnagixLoader.LICENSE \
    && rm -rf /build/openeda/.git /build/openrule/.git /build/anagix/.git \
    && install -d /opt/ossm/immutable/home/.xschem/lib /opt/ossm/immutable/home/.xschem/symbols \
    && cp /build/openeda/xschem/xschemrc_PTC06 /opt/ossm/immutable/home/.xschem/xschemrc \
    && cp /build/openeda/xschem/title_PTC06.sch /opt/ossm/immutable/home/.xschem/ \
    && cp -a /build/openeda/xschem/lib/PTC06/. /opt/ossm/immutable/home/.xschem/lib/ \
    && cp -a /build/openeda/xschem/symbols/. /opt/ossm/immutable/home/.xschem/symbols/ \
    && install -d /opt/ossm/immutable/home/.klayout/salt \
    && cp -a /build/openrule /opt/ossm/immutable/home/.klayout/salt/OpenRule1um \
    && cp -a /build/anagix /opt/ossm/immutable/home/.klayout/salt/AnagixLoader \
    && cp /build/openeda/klayout/klayoutrc /opt/ossm/immutable/home/.klayout/klayoutrc \
    && rm -f /opt/ossm/immutable/home/.klayout/salt/OpenRule1um/tech/tech/lvs/lvs.lylvs \
    && cp /build/openeda/klayout/lvs/or1_lvs.* /opt/ossm/immutable/home/.klayout/salt/OpenRule1um/tech/tech/lvs/ \
    && cp /build/openeda/klayout/macros/get_reference.lym /opt/ossm/immutable/home/.klayout/salt/OpenRule1um/tech/tech/macros/ \
    && install -d /opt/ossm/upstream-templates/chapters/01-inverter \
    && cp -a /build/openeda/samples/inverter/PTC06/. /opt/ossm/upstream-templates/chapters/01-inverter/ \
    && printf '%s\n' \
      "openeda=${OPENEDA_COMMIT}" \
      "openrule1um=${OPENRULE_COMMIT}" \
      "anagix-loader=${ANAGIX_COMMIT}" \
      > /opt/ossm/immutable/PDK_COMMITS \
    && rm -rf /build

COPY TOOLCHAIN.lock /opt/ossm/TOOLCHAIN.lock
COPY gateway/ /opt/ossm/gateway/
COPY scripts/ /opt/ossm/scripts/
COPY supervisor/ /opt/ossm/supervisor/
COPY templates/ /opt/ossm/templates/
COPY web/ /opt/ossm/web/

RUN chmod 0755 /opt/ossm/scripts/* \
    && python3 /opt/ossm/scripts/prepare-openrule-drc.py \
      /opt/ossm/immutable/home/.klayout/salt/OpenRule1um/tech/tech/drc/drc.lydrc \
      /opt/ossm/immutable/openrule.drc \
    && chown -R ato:ato /opt/ossm /home/ato /run/ossm /foss/designs \
    && ln -s /opt/ossm/scripts/labctl /usr/local/bin/labctl

USER 1000:1000
WORKDIR /foss/designs
EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/ossm/scripts/entrypoint.sh"]
