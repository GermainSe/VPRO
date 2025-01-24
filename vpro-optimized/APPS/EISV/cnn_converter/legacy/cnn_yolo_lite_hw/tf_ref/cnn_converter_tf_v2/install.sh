#!/bin/bash
#
# installs dependecies for this project
# requires python, pip3, venv, git
#
# for pycharm:
# Environment: PYTHONUNBUFFERED=1;PYTHONPATH=./tensorflow/models/research:./tensorflow/models/research/slim

# create venv named venv first:
python3 -m venv venv
# if not installed, try:
# virtualenv --python=python3 venv

# get tensorflow object_detection files
#git clone https://github.com/tensorflow/models.git tensorflow/

# install pip dependecies for tf,...
source venv/bin/activate
pip3 install -r requirements.txt

# compile object_detection
#cd tensorflow/models/research/
#protoc object_detection/protos/*.proto --python_out=.
#cd ../../..

echo "OBJECTDETECTLIB=`pwd`/tensorflow/models/research/" >> venv/bin/activate
echo "export PYTHONPATH=\$PYTHONPATH:\$OBJECTDETECTLIB:\$OBJECTDETECTLIB/slim" >> venv/bin/activate


