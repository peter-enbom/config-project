#!/bin/bash
set -e

/usr/bin/git -C /home/db/config-project pull --ff-only origin main
/usr/bin/sudo /usr/bin/cp /home/db/config-project/index.html /srv/www/htdocs/index.html
