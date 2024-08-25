#!/bin/bash

# Ask for the username
read -p "Enter the username to grant passwordless sudo access: " username

# Check if the user exists
if id "$username" >/dev/null 2>&1; then
  # Construct the line to be added to sudoers
  sudo_line="$username ALL=(ALL) NOPASSWD: ALL"

  # Use echo to pipe the line to visudo (handles safety)
  echo "$sudo_line" | sudo EDITOR='tee -a' visudo

  echo "'$username' has been granted passwordless sudo access (use with extreme caution!)."
else
  echo "Error: User '$username' does not exist."
fi