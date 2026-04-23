FROM debian:latest

RUN apt -y update && apt -y upgrade
RUN apt install -y wget iproute2 iputils-ping

WORKDIR  /tmp

RUN wget https://www.multichain.com/download/enterprise/multichain-2.3.3-enterprise-demo.tar.gz
RUN tar -xvzf multichain-2.3.3-enterprise-demo.tar.gz
RUN cd multichain-2.3.3-enterprise-demo && mv multichaind multichain-cli multichain-util /usr/local/bin

EXPOSE 6790 

CMD ["/bin/bash"]




