# PostgreSQL 17 with pgTAP and plpgsql_check, for the dev shell.
{ pkgs }:
pkgs.postgresql_17.withPackages (ps: [
  ps.pgtap
  ps.plpgsql_check
])
