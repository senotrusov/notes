#!/usr/bin/env bash
set -ue
if [ ! -d .venv ]; then
  python3 -m venv .venv
  source .venv/bin/activate
  pip install zensical
else
  source .venv/bin/activate
fi
zensical serve
