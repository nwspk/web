# newspeak.house

## Static content

We have auto-deployment through GitHub Actions from this repository, so we can
make changes to the website directly from here.

* `master` branch deploys to production
* `duck` branch deploys to the duck environment

### Texts

To change texts:

1. Locate view in the [views directory](/app/views/home)
2. Say, one wants to change the text under the "News" section. Locate that in
the [index.html.haml](/app/views/home/index.html.haml) file:
```haml
%h2 News
%p
  Lorem ipsum dolor sit amet consectetur, adipisicing elit. Maiores quo cupiditate iste labore fugiat beatae illum corporis incidunt exercitationem magni. Enim error, id at nam mollitia dolores odit nostrum animi.
```
3. Change it into:
```haml
%h2 News
%p
  We have survived the pandemic.
```

### Images

To add images:

1. Upload new image file in [/app/assets/images/](/app/assets/images).
2. Figure out which one is the page/view in the [views directory](/app/views/home) that will display the new image.
3. Add an image tag like below. NB, the image tag should be on its own line:
```haml
= image_tag('book-logo-black-2.png')
```

### Add new page

To add a new page, say newspeak.house/newproject, one needs to:

1. Create the new file in [/app/views/home/](/app/views/home). Say `/app/views/home/newproject.html.haml`
2. Add a route entry in [/config/routes.rb](/config/routes.rb) for the `home` controller. At the top the `routes.rb` file:
```rb
get 'api/events',               to: 'api#events'
get 'about',                    to: 'home#about', as: :about
get 'fellowship',               to: 'home#fellowship', as: :fellowship
post 'webhooks',                to: 'webhooks#index'
```
Add a new line just under the last `home` controller line (the fellowship one in our example). The new line will look like so:
```rb
get 'newproject',               to: 'home#newproject', as: :newproject
```

## Development

Using Docker:

```sh
docker-compose up --build
```

Set up database:

```sh
docker-compose exec web bundle exec rake db:setup db:migrate
```

To have sidekiq under Docker, create this file `config/initializers/sidekiq.rb`:

```
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
```

## Deployment

This is deployed on an Ubuntu LTS server without Docker.

Steps to set up server:

1. Install PostgreSQL
1. Install Ruby required dependencies:
    * git curl autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev
1. Install [rbenv](https://github.com/rbenv/rbenv)
1. Install Ruby 2.2.4 using rbenv
1. Install bundler v1.17.1
1. Install this repository's ruby dependencies:
    * `bundle install`
1. Copy [.env.example](.env.example) into `.env` and populate environment variables
1. Copy [systemd/](systemd/) files into `/etc/systemd/system/`
1. Enable and start nwspk systemd services:
    * `systemctl enable nwspk-*`
    * `systemctl start nwspk-*`

Tested on Ubuntu 16.04 LTS.
