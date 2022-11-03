FROM ubuntu

COPY . /usr/src/app

RUN apt-get update
RUN apt-get -y install python3-pip