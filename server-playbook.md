# Server Playbook

## Fix DigitalOcean Ubuntu 22.04 sources

This seems like a bug in DigitalOcean (surprisingly).

`apt update` does not work out of the box because of the signature key not
being configured properly.

```sh
apt-key list
sudo apt-key export FAF7EF65 | sudo gpg --dearmour -o /usr/share/keyrings/digitalocean-insights.gpg
# vim /etc/apt/sources.list.d/digitalocean-agent.list
# deb [signed-by=/usr/share/keyrings/digitalocean-insights.gpg] https://repos.insights.digitalocean.com/apt/do-agent main main
apt update
apt upgrade
reboot
```

## Setup PostgreSQL 14

```sh
apt install -y postgresql

sudo -i -u postgres
createuser nwspk
createdb nwspk_production

psql
postgres=# ALTER USER nwspk WITH PASSWORD 'postgres';
postgres=# ALTER DATABASE nwspk_production OWNER TO nwspk;
postgres=# \q

exit
```

## Install redis

redis v6 is in Ubuntu 22.04 repos but we need redis v7 because sidekiq v7
requires redis v7. So, we install redis from `packages.redis.io`.

```sh
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
apt-get update
apt-get install redis
```

## Install Caddy

We use Caddy as a reverse proxy in front of the puma web server.

```sh
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy
```

## Setup application

We use a deploy user, with which GitHub Actions ssh'es into it to pull new
changes.

```sh
adduser deploy # no password
adduser deploy caddy
adduser deploy www-data
cd /var/
mkdir www
chown -R deploy:www-data www
ls -la

sudo -i -u deploy
ssh-keygen -t ed25519
# copy public ssh key into /home/deploy/.ssh/authorized_keys
cat ~/.ssh/id_ed25519.pub

# add private ssh key as github action repository secrets:
# https://github.com/nwspk/web/settings/secrets/actions
cd /var/www/
git clone https://github.com/nwspk/web.git

exit
```

## Install rbenv & ruby

```sh
apt install -y gcc make libz-dev libssl-dev
sudo -i -u deploy
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
exit # relogin to reload new .bashrc
sudo -i -u deploy
rbenv root # verify rbenv exists
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
rbenv install 3.1.3
rbenv global 3.1.3
exit
```

## Configure Caddy

```sh
cp /var/www/web/Caddyfile.example /var/www/web/Caddyfile
vim /var/www/web/Caddyfile
cp /var/www/web/Caddyfile /etc/caddy/
systemctl restart caddy
```

## Start application

```sh
apt install -y libpq-dev # we need this because of the pg gem with native extensions

sudo -i -u deploy

cd /var/www/web/
git checkout staging
cp .envrc.example .envrc # only used for testing / dev server
vim .envrc # add stripe env keys

ruby --version # should be 3.1.3
which ruby # should /home/deploy/.rbenv/shims/ruby
bundle install
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rails server

exit
```

## Install systemd services

```sh
cp /var/www/web/systemd/nwspk-web.example.service /lib/systemd/system/nwspk-web.service
vim /lib/systemd/system/nwspk-web.service # add required env variables in service 
ln -s /lib/systemd/system/nwspk-web.service /etc/systemd/system/multi-user.target.wants/
systemctl daemon-reload
systemctl enable nwspk-web.service
systemctl start nwspk-web.service
systemctl status nwspk-web.service
journalctl -u nwspk-web -f

cp /var/www/web/systemd/nwspk-sidekiq.example.service /lib/systemd/system/nwspk-sidekiq.service
vim /lib/systemd/system/nwspk-sidekiq.service # add required env variables in service 
ln -s /lib/systemd/system/nwspk-sidekiq.service /etc/systemd/system/multi-user.target.wants/
systemctl daemon-reload
systemctl enable nwspk-sidekiq.service
systemctl start nwspk-sidekiq.service
systemctl status nwspk-sidekiq.service
journalctl -u nwspk-sidekiq -f

visudo
# append the following:

# # Allow deploy user to restart apps
# %deploy ALL=NOPASSWD: /usr/bin/systemctl restart nwspk-web.service
# %deploy ALL=NOPASSWD: /usr/bin/systemctl restart nwspk-sidekiq.service
```

## Backup database

```sh
pg_dump -Fc --no-acl nwspk_production -h localhost -U nwspk_production -f /home/deploy/nwspk.dump -W
pg_restore -v -h localhost -cO --if-exists -d nwspk_production -U nwspk -W nwspk.dump
```
