# newspeak.house

## Static content

We have auto-deployment through GitHub Actions from this repository, so we can
make changes to the website directly from here.

* `master` branch deploys to production
* `staging` branch deploys to the staging environment

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

### Styling

The main CSS styling file is
[/app/assets/stylesheets/application.css.scss](/app/assets/stylesheets/application.css).

## Development

Using Docker:

```sh
docker-compose up --build
```

Set up database:

```sh
docker-compose exec web bundle exec rake db:setup db:migrate
```
