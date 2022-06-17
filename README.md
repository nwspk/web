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

## Environment variables

```sh
RAILS_ENV: development
DATABASE_URL: "postgresql://postgres:postgres@database/nwspk_development"
REDIS_URL: "redis://redis:6379/0"
DEAN_USER_ID: 2
CANONICAL_HOST: "https://newspeak.house/"
SIGNUP_FEE: 5000
DEFAULT_USER_EXCLUDE
```
