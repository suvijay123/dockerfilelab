#!/bin/sh
# Use the message passed to `docker run`, or a random fortune if none
MSG="${*:-$(fortune -s)}"

echo
figlet -f slant "Hello Docker" | lolcat -f
echo "$MSG" | cowsay -f /app/whale.cow | lolcat -f
echo
. /etc/os-release
echo "  Container ID : $(hostname)" | lolcat -f
echo "  Running on   : $PRETTY_NAME (even if your laptop is Windows or Mac!)" | lolcat -f
echo
