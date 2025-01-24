FROM debian:bullseye

MAINTAINER Alexander Köhne version: 4.1

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
RUN apt-get install -y git make gcc g++ wget libopencv-dev nano libboost-all-dev
RUN apt-get install -y python3 python3-pip python3-venv cmake qtbase5-dev libpng++-dev
RUN apt-get install -y colordiff
RUN rm -rf /var/lib/apt/lists/*

RUN pip3 install poetry

WORKDIR /nn_quant_poetry_init/

COPY nn_quant.install .
RUN mv nn* pyproject.toml
RUN python3 -m venv init_env
RUN . init_env/bin/activate && poetry install

WORKDIR /prj/

CMD ["bash"]
