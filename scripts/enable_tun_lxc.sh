#!/bin/bash

# Prompt the user for the LXC container number
read -p "Enter LXC container number: " container_number

# Construct the path to the LXC configuration file
config_file="/etc/pve/lxc/${container_number}.conf"

# Check if the configuration file exists
if [ ! -f "$config_file" ]; then
  echo "Error: Configuration file '$config_file' not found."
  exit 1
fi

# Check if the lines are already present in the config file
if grep -qE '^# lxc.cgroup.devices.allow: c 10:200 rwm$' "$config_file" && grep -qE '^# lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file$' "$config_file"; then
  echo "Lines already exist in '$config_file'. Skipping."
else
  # Append the lines to the configuration file
  echo "# lxc.cgroup.devices.allow: c 10:200 rwm" >> "$config_file"
  echo "# lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> "$config_file"

  echo "Successfully added lines to '$config_file'."
fi