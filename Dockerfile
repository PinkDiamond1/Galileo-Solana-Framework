# get the caddy executable
FROM caddy AS caddy-build

# get the go runtime
FROM golang as go

# get the Galileo IDE
FROM hypernetlabs/galileo-ide:linux AS galileo-ide

# # get metrics binaries
# FROM ubuntu:18.04 as metrics
	
# # get prometheus metrics monitoring
# ADD https://github.com/prometheus/prometheus/releases/download/v2.27.1/prometheus-2.27.1.linux-amd64.tar.gz .
# RUN tar -xvf prometheus-2.27.1.linux-amd64.tar.gz
# RUN sed -i 's/localhost:9090,/localhost:9900,/g' /prometheus-2.27.1.linux-amd64/prometheus.yml
# RUN ls -la

# Final build stage
FROM ubuntu:18.04 

# install geth, python, node, and smart contract development tooling
RUN apt update -y \
  && apt install -y software-properties-common gpg \
  && add-apt-repository -y ppa:deadsnakes/ppa \
  && add-apt-repository -y ppa:ethereum/ethereum \ 
  && apt update -y \
  && apt install -y \
    ethereum solc \
    supervisor kmod fuse\
    python3.8 python3-pip python3.8-dev \
    libsecret-1-dev \
	vim curl tmux git zip unzip vim speedometer net-tools \
  && python3.8 -m pip install web3 py-solc py-solc-x \
  && curl -fsSL https://deb.nodesource.com/setup_12.x | bash - \
  && apt install -y nodejs \
  && npm install -g solc \
  && curl https://rclone.org/install.sh | bash \
  && rm -rf /var/lib/apt/lists/*

# get the go runtime
COPY --from=go /go /go
COPY --from=go /usr/local/go /usr/local/go
ENV PATH $PATH:/usr/local/go/bin:/home/galileo:/home/galileo/.local/bin

RUN useradd -ms /bin/bash galileo

COPY --chown=galileo .theia /home/galileo/.theia

# get the Caddy server executable
# copy the caddy server build into this container
COPY --from=caddy-build --chown=galileo /usr/bin/caddy /usr/bin/caddy
COPY --chown=galileo rclone.conf /home/galileo/.config/rclone/rclone.conf
COPY --chown=galileo Caddyfile /etc/

# get the galileo IDE
COPY --from=galileo-ide --chown=galileo /.galileo-ide /home/galileo/.galileo-ide

USER galileo
WORKDIR /home/galileo/.galileo-ide

# get supervisor configuration file
COPY supervisord.conf /etc/

WORKDIR /home/galileo/.galileo-ide

# set environment variable to look for plugins in the correct directory
ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/galileo/.galileo-ide/plugins
ENV USE_LOCAL_GIT true
ENV GALILEO_RESULTS_DIR /home/galileo

# set login credentials and write them to text file
# ENV USERNAME "a"
# ENV PASSWORD "a"
# RUN echo "basicauth /* {" >> /tmp/hashpass.txt && \
    # echo "    {env.USERNAME}" $(caddy hash-password -plaintext $(echo $PASSWORD)) >> /tmp/hashpass.txt && \
    # echo "}" >> /tmp/hashpass.txt

ENTRYPOINT ["sh", "-c", "supervisord"]