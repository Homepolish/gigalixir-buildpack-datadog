#!/usr/bin/env bash

# Setup Locations
APT_DIR="$HOME/.apt"
DD_DIR="$APT_DIR/opt/datadog-agent"
DD_BIN_DIR="$DD_DIR/bin/agent"
DD_LOG_DIR="$APT_DIR/var/log/datadog"
DD_CONF_DIR="$APT_DIR/etc/datadog-agent"
export DATADOG_CONF="$DD_CONF_DIR/datadog.yaml"

# Update Env Vars with new paths for apt packages
export PATH="$APT_DIR/usr/bin:$DD_BIN_DIR:$PATH"
export LD_LIBRARY_PATH="$APT_DIR/usr/lib/x86_64-linux-gnu:$APT_DIR/usr/lib:$LD_LIBRARY_PATH"
export LIBRARY_PATH="$APT_DIR/usr/lib/x86_64-linux-gnu:$APT_DIR/usr/lib:$LIBRARY_PATH"
export INCLUDE_PATH="$APT_DIR/usr/include:$APT_DIR/usr/include/x86_64-linux-gnu:$INCLUDE_PATH"
export PKG_CONFIG_PATH="$APT_DIR/usr/lib/x86_64-linux-gnu/pkgconfig:$APT_DIR/usr/lib/pkgconfig:$PKG_CONFIG_PATH"

# Set Datadog configs
export DD_LOG_FILE="$DD_LOG_DIR/datadog.log"

# Ensure all check and librariy locations are findable in the Python path.
DD_PYTHONPATH="$DD_DIR/embedded/lib/python2.7"
# Recursively add packages to python path.
DD_PYTHONPATH="$DD_PYTHONPATH$(find "$DD_DIR/embedded/lib/python2.7/site-packages" -maxdepth 1 -type d -printf ":%p")"
# Add other packages.
DD_PYTHONPATH="$DD_DIR/embedded/lib/python2.7/plat-linux2:$DD_PYTHONPATH"
DD_PYTHONPATH="$DD_DIR/embedded/lib/python2.7/lib-tk:$DD_PYTHONPATH"
DD_PYTHONPATH="$DD_DIR/embedded/lib/python2.7/lib-dynload:$DD_PYTHONPATH"
export DD_PYTHONPATH="$DD_DIR/bin/agent/dist:$DD_PYTHONPATH"