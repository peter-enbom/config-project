#!/bin/bash
set -e

git -C /home/db/config-project pull --ff-only origin main
sudo cp /home/db/config-project/index.html /srv/www/htdocs/index.html
