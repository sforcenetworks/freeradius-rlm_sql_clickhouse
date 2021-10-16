FROM ghcr.io/sforcenetworks/freeradius:3.0.21-dfsg-2.2-sforcenetworks1

COPY sql-clickhouse /etc/freeradius/3.0/mods-enabled/sql
COPY clients.conf /etc/freeradius/3.0/clients.conf

RUN chown freerad.freerad -R /etc/freeradius/3.0 \
  && chmod o-w -R /etc/freeradius/3.0
