# get the go runtime
FROM golang as go

# get the Galileo IDE
FROM hypernetlabs/galileo-ide:linux AS galileo-ide

# Final build stage
FROM ubuntu:18.04 

# install geth, python, node, and smart contract development tooling
RUN apt update -y \
  && apt install -y software-properties-common gpg \
  && add-apt-repository -y ppa:deadsnakes/ppa \
  && add-apt-repository -y ppa:ethereum/ethereum \ 
  && apt update -y \
  && apt install -y \
    supervisor kmod fuse\
    python3.8 python3-pip python3.8-dev \
    libsecret-1-dev \
	vim curl tmux git zip unzip vim speedometer net-tools \
  && curl -fsSL https://deb.nodesource.com/setup_12.x | bash - \
  && apt install -y nodejs \
  && curl https://rclone.org/install.sh | bash \
  && rm -rf /var/lib/apt/lists/*

# get the go runtime
COPY --from=go /go /go
COPY --from=go /usr/local/go /usr/local/go
ENV PATH $PATH:/usr/local/go/bin:/home/galileo:/home/galileo/.local/bin
ENV GOPATH=/usr/local/go

RUN go get -u github.com/bitnami/bcrypt-cli

RUN useradd -ms /bin/bash galileo

COPY --chown=galileo .theia /home/galileo/.theia
COPY --chown=galileo .vscode /home/galileo/.vscode

# get the Caddy server executables and stuff
COPY --from=galileo-ide --chown=galileo /caddy/caddy /usr/bin/caddy
COPY --from=galileo-ide --chown=galileo /caddy/header.html /etc/assets/header.html
COPY --from=galileo-ide --chown=galileo /caddy/users.json /etc/gatekeeper/users.json
COPY --from=galileo-ide --chown=galileo /caddy/auth.txt /etc/gatekeeper/auth.txt
COPY --from=galileo-ide --chown=galileo /caddy/settings.template /etc/gatekeeper/assets/settings.template
COPY --from=galileo-ide --chown=galileo /caddy/login.template /etc/gatekeeper/assets/login.template
COPY --from=galileo-ide --chown=galileo /caddy/custom.css /etc/assets/custom.css
COPY --chown=galileo rclone.conf /home/galileo/.config/rclone/rclone.conf
COPY --chown=galileo Caddyfile /etc/

# get the galileo IDE
COPY --from=galileo-ide --chown=galileo /.galileo-ide /home/galileo/.galileo-ide

RUN npm install -g mocha && npm i -g @project-serum/anchor-cli

USER galileo
WORKDIR /home/galileo/.galileo-ide

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="/home/galileo/.cargo/bin:${PATH}"
RUN rustup component add rustfmt

RUN sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
ENV PATH="/home/galileo/.local/share/solana/install/active_release/bin:${PATH}"

# get supervisor configuration file
COPY supervisord.conf /etc/

WORKDIR /home/galileo/.galileo-ide

# set environment variable to look for plugins in the correct directory
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/galileo/.galileo-ide/plugins
ENV USE_LOCAL_GIT true
ENV GALILEO_RESULTS_DIR /home/galileo

# set login credentials and write them to text file
# ENV USERNAME "tnyugen+3@hypernetlabs.io"
# ENV PASSWORD "a"
# RUN sed -i 's,"username": "","username": "'"$USERNAME"'",1' /etc/gatekeeper/users.json && \
    # sed -i 's,"hash": "","hash": "'"$(echo -n "$(echo $PASSWORD)" | bcrypt-cli -c 10 )"'",1' /etc/gatekeeper/users.json

ENTRYPOINT ["sh", "-c", "supervisord"]