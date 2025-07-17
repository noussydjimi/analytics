FROM ubuntu:22.04 AS base
LABEL maintainer="Gilles Djimi <djimigilles@gmail.com>"
LABEL stage="builder"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        software-properties-common \
        gnupg2

RUN add-apt-repository universe && \
    apt-get update && \
    apt-get install -y python2 python2-dev python2-minimal && \
    curl -sS https://bootstrap.pypa.io/pip/2.7/get-pip.py | python2

RUN apt-get install -y python3 python3-pip python3-dev

RUN pip2 install --upgrade pip && pip3 install --upgrade pip

RUN apt-get update && \
    apt-get install -y --no-install-recommends r-base r-base-dev

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --ignore-installed -r /tmp/requirements.txt


FROM ubuntu:22.04
LABEL maintainer="Gilles Djimi <djimigilles@gmail.com>"

COPY --from=base /usr /usr
COPY --from=base /etc /etc
COPY --from=base /var/lib/dpkg /var/lib/dpkg

RUN groupadd --system analytics && \
    useradd  --system --gid analytics --create-home analytics

WORKDIR /workspace

RUN pip3 install prometheus_client==0.22.1
RUN which python3
RUN python3 -m site
RUN pip3 show prometheus_client
RUN python3 -c "import prometheus_client; print('prometheus_client is installed')"

COPY requirements.txt requirements.txt
RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip2 install prometheus-client

COPY metrics_server.py /workspace/
RUN chown -R analytics:analytics /home/analytics
USER analytics
EXPOSE 8000
CMD ["python3", "/workspace/metrics_server.py"]
