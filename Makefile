pginit:
	PGDATA=postgres-data/ pg_ctl init
	PGDATA=postgres-data/ pg_ctl start

pgstart:
	PGDATA=postgres-data/ pg_ctl start

pgstop:
	PGDATA=postgres-data/ pg_ctl stop
