#!/bin/bash
cd $PT_deploydir
touch bolt.yaml
bolt puppetfile install -m ../..
