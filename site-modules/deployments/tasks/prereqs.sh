#!/bin/bash
if !(dpkg -l git); then
  apt-get update && apt-get install -y git
fi
