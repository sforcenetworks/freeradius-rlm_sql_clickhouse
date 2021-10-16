#ifndef __SQL_CLICKHOUSE_H
#ifdef __cplusplus

extern "C" {
#endif

typedef void* ClickhouseClient;
typedef char* ClickhouseErrorMsg;

ClickhouseClient NewClickhouseClient(char const *host,
                                     unsigned int port,
                                     char const *user,
                                     char const *password,
                                     ClickhouseErrorMsg errMsg,
                                     size_t errLen);
bool ClickhouseClientExecute(ClickhouseClient client, char const *query,
                             ClickhouseErrorMsg errMsg, size_t errLen);
bool ClickhouseClientSelect(ClickhouseClient client, char const *query,
                            ClickhouseErrorMsg errMsg, size_t errLen);
void ClickhouseClientClose(ClickhouseClient client);

#ifdef __cplusplus
}
#endif
#endif // __SQL_CLICKHOUSE_H
