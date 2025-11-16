#!/bin/bash
# filepath: /home/paul/repos/linux-how-to/09-test-access-to-sites/bash/testsites_csv.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <user_sites.csv> [unexpected_only]"
  exit 1
fi

CSV="$1"
UNEXPECTED_ONLY=0

if [ "$2" == "unexpected_only" ]; then
  UNEXPECTED_ONLY=1
fi

# Skip header and comments, then process each line
tail -n +2 "$CSV" | grep -v '^#' | while IFS=',' read -r user access site; do
  # Remove possible whitespace
  user=$(echo "$user" | xargs)
  access=$(echo "$access" | xargs)
  site=$(echo "$site" | xargs)

  if [ -z "$user" ] || [ -z "$access" ] || [ -z "$site" ]; then
    continue
  fi

  if [ "$access" == "allow" ]; then
    if curl -s --head --fail "$site" > /dev/null; then
      if [ $UNEXPECTED_ONLY -eq 0 ]; then
        echo -e "[$user]\tALLOWED\t${GREEN}\t$site\tis accessible \texpected\t${NC}"
      fi
    else
      echo -e "[$user]\tALLOWED\t${RED}\t$site\tis NOT accessible \tunexpected!\t${NC}"
    fi
  elif [ "$access" == "deny" ]; then
    if curl -s --head --fail "$site" > /dev/null; then
      echo -e "[$user]\tDENIED\t${RED}\t$site\tis accessible \tunexpected!\t${NC}"
    else
      if [ $UNEXPECTED_ONLY -eq 0 ]; then
        echo -e "[$user]\tDENIED\t${GREEN}\t$site\tis NOT accessible \texpected\t${NC}"
      fi
    fi
  fi
done