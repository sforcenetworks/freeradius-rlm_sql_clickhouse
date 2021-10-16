/*
 * sql_clickhouse.cxx		Clickhouse rlm_sql driver
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

#include <clickhouse/client.h>
#include <clickhouse/error_codes.h>
#include <clickhouse/types/type_parser.h>

#include <cstdio>

#include "sql_clickhouse.h"

using namespace clickhouse;
using namespace std;

extern "C" ClickhouseClient
NewClickhouseClient(char const *host,
                    unsigned int port,
                    char const *user,
                    char const *password,
                    ClickhouseErrorMsg errMsg,
                    size_t errLen) {
	try {
    ClientOptions options = ClientOptions()
			.SetHost(host)
      .SetPort(port)
			.TcpKeepAlive(true)
			.SetCompressionMethod(CompressionMethod::LZ4);

    if (user && password) {
      options
        .SetUser(user)
        .SetPassword(password);
    }

		Client* client = new Client(options);

		return static_cast<ClickhouseClient>(client);
	} catch (const std::exception& e) {
		snprintf(errMsg, errLen, "%s", e.what());
		return NULL;
	}
}

extern "C" bool
ClickhouseClientExecute(ClickhouseClient client, char const *query,
                        ClickhouseErrorMsg errMsg, size_t errLen) {
	Client *c = static_cast<Client *>(client);

	try {
		c->Execute(query);
		return true;
	} catch (const std::exception& e) {
		snprintf(errMsg, errLen, "%s", e.what());
		return false;
	}
}

extern "C" bool
ClickhouseClientSelect(ClickhouseClient client, char const *query,
                       ClickhouseErrorMsg errMsg, size_t errLen) {
	Client *c = static_cast<Client *>(client);

	try {
		c->Select(query, [](const Block& block) {

		});
		return true;
	} catch (const std::exception& e) {
		snprintf(errMsg, errLen, "%s", e.what());
		return false;
	}
}


extern "C" void
ClickhouseClientClose(ClickhouseClient client) {
	Client *c = static_cast<Client *>(client);

  delete c;
}
