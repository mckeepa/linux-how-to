#!/bin/bash
# filepath: /home/paul/repos/linux-how-to/09-test-access-to-sites/bash/testsites.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <user_sites.json> [unexpected_only]"
  exit 1
fi

CONFIG="$1"
UNEXPECTED_ONLY=0

if [ "$2" == "unexpected_only" ]; then
  UNEXPECTED_ONLY=1
fi

users=$(jq -r 'keys[]' "$CONFIG")

for user in $users; do
  allow_sites=$(jq -r --arg user "$user" '.[$user].allow[]?' "$CONFIG")
  deny_sites=$(jq -r --arg user "$user" '.[$user].deny[]?' "$CONFIG")

  for site in $allow_sites; do
    if curl -s --head --fail "$site" > /dev/null; then
      if [ $UNEXPECTED_ONLY -eq 0 ]; then
        echo -e "[$user]\tALLOWED\t${GREEN}$site\tis accessible \texpected${NC}"
      fi
    else
      echo -e "[$user]\tALLOWED\t${RED}$site\tis NOT accessible \tunexpected!${NC}"
    fi
  done

  for site in $deny_sites; do
    if curl -s --head --fail "$site" > /dev/null; then
      echo -e "[$user]\tDENIED\t${RED}$site\tis accessible \tunexpected!${NC}"
    else
      if [ $UNEXPECTED_ONLY -eq 0 ]; then
        echo -e "[$user]\tDENIED\t${GREEN}$site\tis NOT accessible \texpected${NC}"
      fi
    fi
  done
done