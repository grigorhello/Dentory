-- Proves the pgTAP pipeline runs. Real schema tests arrive with MS-104.
begin;
select plan(2);

select has_schema('public', 'the public schema exists');
select ok(current_setting('server_version_num')::int >= 170000, 'Postgres 17 or later, as config.toml pins');

select * from finish();
rollback;
