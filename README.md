# newspeak.house

## Development

Using Docker:

```sh
docker-compose up --build
```

Set up database:

```sh
docker-compose exec web bundle exec rake db:setup db:migrate
```
