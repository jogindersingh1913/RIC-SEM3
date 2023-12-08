FROM ubuntu:latest

RUN apt-get update && apt-get install -y procps && apt-get install -y sysbench
