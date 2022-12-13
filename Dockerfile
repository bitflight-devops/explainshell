# (nop) ADD file:592c2540de1c707636622213ee30ff5b6f8be0a48bb25c97edc7204ea4df1a81 in /
FROM spaceinvaderone/explainshell AS explainshell
FROM ubuntu:20.04
ENV NONINTERACTIVE=1 \
    DEBIAN_FRONTEND=noninteractive \
    JSYAML_VERSION=4.1.0 \
    GOSU_VERSION=1.14 \
    MONGO_REPO=repo.mongodb.org \
    MONGO_PACKAGE=mongodb-org-unstable \
    MONGO_MAJOR=6.0.3 \
    NODEJS_VERSION=12.* \
    TINI_VERSION=v0.19.0 \
    SHELL_SCRIPTS_BRANCH=feat/eb_validation_test \
    GPG_KEYS=BD8C80D9C729D00524E068E03DAB71713396F72B

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]
SHELL ["/bin/bash", "-c"]
COPY root/usr/sbin/policy-rc.d /usr/sbin/policy-rc.d
COPY root/etc/dpkg/dpkg.cfg.d/docker-apt-speedup /etc/dpkg/dpkg.cfg.d/docker-apt-speedup
COPY root/etc/apt/apt.conf.d/docker-clean /etc/apt/apt.conf.d/docker-clean
COPY root/etc/apt/apt.conf.d/docker-autoremove-suggests /etc/apt/apt.conf.d/docker-autoremove-suggests
COPY root/etc/apt/apt.conf.d/docker-no-languages /etc/apt/apt.conf.d/docker-no-languages
COPY root/etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-gzip-indexes

RUN set -xe \
    ls -lah ~/keys; \
    chmod +x /usr/sbin/policy-rc.d \
    && dpkg-divert --local --rename --add /sbin/initctl \
    && cp -a /usr/sbin/policy-rc.d /sbin/initctl \
    && sed -i 's/^exit.*/exit 0/' /sbin/initctl
RUN sed -i 's/^#\\s*\\(deb.*universe\\)$/\\1/g' /etc/apt/sources.list \
    && mkdir -p /run/systemd && echo 'docker' > /run/systemd/container \
    && groupadd -r mongodb && useradd -r -g mongodb mongodb \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    gnupg2 \
    curl \
    bash \
    ca-certificates \
    && curl -sSLl https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - \
    && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null \
    && curl -sSLl https://keys.openpgp.org/vks/v1/by-fingerprint/B42F6819007F00F88E364FD4036A9C25BF357DD4 | apt-key add - \
    && rm -rf /var/lib/apt/lists/*
COPY root/etc/apt/sources.list.d/mongodb-org-6.0.list /etc/apt/sources.list.d/mongodb-org-6.0.list
RUN mkdir -p ~/bitflight-devops \
    && curl -sSlL https://raw.githubusercontent.com/bitflight-devops/shell-scripts/${SHELL_SCRIPTS_BRANCH:-main}/install.sh -o ~/bitflight-devops/install.sh \
    && source ~/bitflight-devops/install.sh \
    && source ~/.local/bitflight-devops/shell-scripts/.shellscriptsrc \
    && echo "source ~/.local/bitflight-devops/shell-scripts/.shellscriptsrc" >> ~/.bashrc \
    && install_apt-fast

RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - ; \
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list > /dev/null

RUN apt-get update \
    && source ~/.local/bitflight-devops/shell-scripts/.shellscriptsrc \
    && package_manager install \
    wget \
    jq \
    perl \
    coreutils \
    numactl \
    gosu \
    yarn \
    make \
    nodejs \
    man-db \
    netcat \
    python2 \
    git \
    mongodb-org="${MONGO_MAJOR}" \
    mongodb-org-database="${MONGO_MAJOR}" \
    mongodb-org-server="${MONGO_MAJOR}" \
# mongodb-mongosh="${MONGO_MAJOR}" \
    mongodb-org-mongos="${MONGO_MAJOR}" \
    mongodb-org-tools="${MONGO_MAJOR}" \
    && rm -rf /var/lib/apt/lists/*; \
# nvm install "${NODEJS_VERSION}" \
# verify that the binary works
    curl -sSlL https://bootstrap.pypa.io/pip/2.7/get-pip.py | python2 -;
RUN gosu nobody:root bash -c 'whoami && id';

RUN curl -sSlL -o /js-yaml.js "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/dist/js-yaml.js";

RUN mkdir -p /docker-entrypoint-initdb.d
RUN set -ex; \
# mkdir -p /etc/apt/trusted.gpg.d/; \
# export GNUPGHOME="$(mktemp -d)"; \
# for key in $GPG_KEYS; do \
# gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
# done; \
# gpg --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mongodb.gpg; \
# rm -r "$GNUPGHOME"; \
# apt-key list \
# && rm -rf /var/lib/apt/lists/* \
    rm -rf /var/lib/mongodb; \
    if [ -f /etc/mongod.conf ]; then mv /etc/mongod.conf /etc/mongod.conf.orig; fi;

RUN mkdir -p \
    /data/db2 \
    /data/db \
    /data/configdb \
    ~/explainshell \
    ~/bash-language-server \
    && chown -R mongodb:mongodb /data/db  /data/db2 /data/configdb \
    && echo \"dbpath = /data/db2\" > /etc/mongodb.conf
COPY --from=explainshell /explainshell /explainshell
COPY --from=explainshell /bash-language-server /bash-language-server
RUN cd /explainshell \
    && pip install --no-cache-dir -r requirements.txt

# RUN git clone https://github.com/chrismwendt/bash-language-server \
# &&
# g

RUN cd bash-language-server \
    && npm config set python $(which python2) \
    && npm i -g npm-check-updates \
    && ncu -u \
    && make build \
    && make install \
    && make clean \
    && yarn global add file:"$(pwd)"/server
COPY ./populate-explainshell.sh /populate-explainshell.sh
COPY ./run-bash-language-server.sh /run-bash-language-server.sh
COPY ./start.sh ./start.sh
COPY ./setup.sh ./setup.sh
# (nop) COPY dir:4ea9422aec60af63924a8e239f2739a7fb5179c127bfc518e0f985d54ce7f5b9 in .
RUN cd /explainshell && ../populate-explainshell.sh
# (nop) COPY file:d663dcc05f335c55f2b6a020f7888502735051625e9145a6ac5ed8b300423f2a in /usr/local/bin "
COPY root/usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["/usr/local/bin/docker-entrypoint.sh"]
