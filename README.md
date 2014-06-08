slacheck
========

A simple Bash script for monitoring and logging the availability
of network services. Current status: proof of concept ;-)


Requirements
------------

 + Bash
 + CURL
 + Cron



Installation
------------

~~~~ bash
wget -O /tmp/slacheck.zip https://github.com/websafe/slacheck/archive/develop.zip
unzip -d /tmp /tmp/slacheck.zip
mv /tmp/slacheck-develop /etc/slacheck
chown -Rv root:root /etc/slacheck
cp /etc/slacheck/slacheck-http-cron-dist /etc/cron.d/slacheck-http-cron
~~~~


Now edit `/etc/cron.d/slacheck-http-cron` and restart `crond`.

