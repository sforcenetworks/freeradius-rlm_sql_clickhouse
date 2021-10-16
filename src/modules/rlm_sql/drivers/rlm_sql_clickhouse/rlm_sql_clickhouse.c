/*
 * sql_clickhouse.c		Clickhouse rlm_sql driver
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 *
 * Copyright 2020  Neutron Soutmun <neutron@neutron.in.th>
 */

#include <freeradius-devel/radiusd.h>
#include <freeradius-devel/rad_assert.h>

#include <sys/stat.h>

#include "rlm_sql.h"
#include "sql_clickhouse.h"

typedef struct {
  char const   *host;
  unsigned int port;
  char const   *user;
  char const   *password;
} rlm_sql_clickhouse_config_t;

typedef struct {
	ClickhouseClient	*client;
} rlm_sql_clickhouse_conn_t;

static const CONF_PARSER driver_config[] = {
  { "host", FR_CONF_OFFSET(PW_TYPE_STRING | PW_TYPE_REQUIRED, rlm_sql_clickhouse_config_t, host), NULL},
  { "port", FR_CONF_OFFSET(PW_TYPE_INTEGER, rlm_sql_clickhouse_config_t, port), 9000},
  { "user", FR_CONF_OFFSET(PW_TYPE_STRING, rlm_sql_clickhouse_config_t, user), NULL},
  { "password", FR_CONF_OFFSET(PW_TYPE_STRING, rlm_sql_clickhouse_config_t, password), NULL},
	CONF_PARSER_TERMINATOR
};

static int mod_instantiate(CONF_SECTION *conf, rlm_sql_config_t *config)
{
	rlm_sql_clickhouse_config_t *driver;

	MEM(driver = config->driver = talloc_zero(config, rlm_sql_clickhouse_config_t));
	if (cf_section_parse(conf, driver, driver_config) < 0) {
		return -1;
	}

	return 0;
}

static int _clickhouse_client_close(rlm_sql_clickhouse_conn_t *conn)
{
	DEBUG2("rlm_sql_clickhouse: Client destructor called, closing the client's connectin");

	if (!conn->client) return 0;

	ClickhouseClientClose(conn->client);
	return 0;
}


static int CC_HINT(nonnull) sql_socket_init(rlm_sql_handle_t *handle, rlm_sql_config_t *config)
{
	rlm_sql_clickhouse_config_t *driver = config->driver;
	rlm_sql_clickhouse_conn_t *conn;

	MEM(conn = handle->conn = talloc_zero(handle, rlm_sql_clickhouse_conn_t));
	talloc_set_destructor(conn, _clickhouse_client_close);

	DEBUG2("rlm_sql_clickhouse: Connecting to database");

	char err_msg[256];
	conn->client = NewClickhouseClient(driver->host,
                                     driver->port,
                                     driver->user,
                                     driver->password,
                                     err_msg,
                                     sizeof(err_msg));
	if (!conn->client) {
		ERROR("rlm_sql_clickhouse: Connection failed - %s", err_msg);
	}

	DEBUG2("rlm_sql_clickhouse: Connected to database");

	return 0;
}

static CC_HINT(nonnull) sql_rcode_t sql_query(rlm_sql_handle_t *handle, UNUSED rlm_sql_config_t *config,
					      char const *query)
{
	rlm_sql_clickhouse_conn_t *conn = handle->conn;

	if (!conn->client) {
		ERROR("rlm_sql_lighthouse: No client connection");
		return RLM_SQL_RECONNECT;
	}

	char err_msg[256];
	if (!ClickhouseClientExecute(conn->client, query, err_msg, sizeof(err_msg))) {
		ERROR("rlm_sql_lighthouse: Query error - %s", err_msg);
		return RLM_SQL_ERROR;
	}

	return RLM_SQL_OK;
}

static sql_rcode_t sql_select_query(rlm_sql_handle_t * handle, rlm_sql_config_t *config, char const *query)
{
	rlm_sql_clickhouse_conn_t *conn = handle->conn;

	if (!conn->client) {
		ERROR("rlm_sql_lighthouse: No client connection");
		return RLM_SQL_RECONNECT;
	}

	char err_msg[256];
	if (!ClickhouseClientSelect(conn->client, query, err_msg, sizeof(err_msg))) {
		ERROR("rlm_sql_lighthouse: Query error - %s", err_msg);
		return RLM_SQL_ERROR;
	}

	return RLM_SQL_OK;
}

static int sql_num_fields(rlm_sql_handle_t * handle, UNUSED rlm_sql_config_t *config)
{
	// Not Support
  return 0;
}

static sql_rcode_t sql_fetch_row(rlm_sql_handle_t *handle, UNUSED rlm_sql_config_t *config)
{
	// Not Support
	return RLM_SQL_NO_MORE_ROWS;
}

static size_t sql_error(TALLOC_CTX *ctx, sql_log_entry_t out[], size_t outlen,
			rlm_sql_handle_t *handle, UNUSED rlm_sql_config_t *config)
{
	// Not Support
	return 0;
}

static sql_rcode_t sql_free_result(rlm_sql_handle_t * handle, UNUSED rlm_sql_config_t *config)
{
	// Not Support
	return 0;
}

static int sql_affected_rows(rlm_sql_handle_t * handle, UNUSED rlm_sql_config_t *config)
{
	// Not Support
	return 0;
}

static size_t sql_escape_func(UNUSED REQUEST *request, char *out, size_t outlen, char const *in, void *arg)
{
	// Not Support
	return strlen(in);
}

/* Exported to rlm_sql */
extern rlm_sql_module_t rlm_sql_clickhouse;
rlm_sql_module_t rlm_sql_clickhouse = {
	.name				= "rlm_sql_clickhouse",
	.mod_instantiate		= mod_instantiate,
	.sql_socket_init		= sql_socket_init,
	.sql_query			    = sql_query,
	.sql_select_query		= sql_select_query,
	.sql_num_fields			= sql_num_fields,
	.sql_fetch_row			= sql_fetch_row,
	.sql_error			    = sql_error,
	.sql_finish_query		= sql_free_result,
	.sql_finish_select_query	= sql_free_result,
	.sql_affected_rows	= sql_affected_rows,
	.sql_escape_func		= sql_escape_func
};
