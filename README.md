# bridge-management

Alpha v0.2.3

<img width="1132" alt="Screenshot 2023-11-25 at 2 40 06 PM" src="https://github.com/emeraldonion/bridge-management/assets/8809920/333563f7-7608-4afe-9d5c-47e356907a83">


This shell script aims to make it easier to deploy and manage Tor obfs4 bridges. The inspiration for this script comes from years of being annoyed with Tor's UI and UX for bridge operators.

Bridge deployment only asks for the following things:

- Bridge name
- IPv4 address
- IPv6 address
- obfs4 port (including low ports such as 443)
- Contact Info (email)
- Bridge Distribution method (https/moat/email/telegram/settings/none/any)

This script only sets up an obfs4 bridge. No plain bridge. No other pluggable transports. If there are other options that you would like to manually tune, you'll have to go into the respective torrc file and make manual changes. Making changes to the torrc file should not affect the script.

What it does do (as root):

1. Checks if Tor is installed. If not, it installs it.
2. Checks if obfs4proxy is installed. If not installs it.
3. Configures obfs4proxy to be allowed to bind to low ports.
4. Prints existing bridges made from `tor-instance-create`. What it prints is a complete line needed for copying+pasting into Tor Browser when manually configuring a Private Bridge.
5. Asks: Add, Delete, or List bridges.
6. When you add a new Bridge, it prints the new torrc file for easy reading, and it prints the torrc directory location for any necessary manual editing.

# Install

Validated working on modern Debian and Ubuntu server systems:

`sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/emeraldonion/bridge-management/main/bridge-management.sh)"`

