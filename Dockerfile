FROM ubuntu

RUN apt-get update

ENTRYPOINT ["/tf-modules/lambda/scripts/create_pkg.sh"]