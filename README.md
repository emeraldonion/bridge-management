# bridge-management

This script aims to make it easier to deploy and manage Tor obfs4 bridges. The inspiration for this script comes from years of being annoyed with Tor's UI and UX for bridge operators.

Bridge deployment only asks for the following things:

- Bridge name
- IP
- obfs4 port
- Contact Info (email)
- Bridge Distribution method (https/moat/email/telegram/settings/none/any)

As such, the script, in its current form, only sets up an obfs4 bridge with no plain bridge. No other pluggable transports currently. If there are other options that you need to manually tune, you'll have to go into the respective torrc file and make manual changes. However, making these changes will not affect the current functions of the script.

What it does do (as root):

1. Checks if Tor is installed. If not, it installs it.
2. Checks if obfs4proxy is installed. If not installs it.
3. Prints existing bridges made from `tor-instance-create`.
4. Asks: Add, Delete, or List bridges.

I welcome feedback and contributions!

- @yawnbox
