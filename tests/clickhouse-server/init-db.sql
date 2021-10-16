CREATE TABLE radacct_raw
(
  EventTimestamp   DateTime DEFAULT now() CODEC(DoubleDelta),
  AcctSessionId    String,
  AcctUniqueId     String,
  UserName         String,
  Realm            String,
  NASIPAddress     Nullable(IPv6),
  NASPortId        Nullable(String),
  NASPortType      Nullable(String),
  AcctStatusType   String,
  AcctStartTime    Nullable(Datetime),
  AcctStopTime     Nullable(Datetime),
  AcctTerminateCause   Nullable(String),
  AcctAuthentic        Nullable(String),
  ConnectInfoStart     Nullable(String),
  ConnectInfoStop      Nullable(String),
  AcctInputOctets      UInt64,
  AcctOutputOctets     UInt64,
  CalledStationId      Nullable(String),
  CallingStationId     Nullable(String),
  ServiceType          Nullable(String),
  FramedProtocol       Nullable(String),
  FramedIPAddress      Nullable(IPv4),
  FramedIPv6Address    Nullable(IPv6),
  FramedIPv6Prefix     Nullable(IPv6),
  FramedIPv6PrefixSize Nullable(UInt8),
  FramedInterfaceId    Nullable(String),
  DelegatedIPv6Prefix  Nullable(IPv6),
  DelegatedIPv6PrefixSize Nullable(UInt8)
)
ENGINE = MergeTree
PARTITION BY tuple()
ORDER BY tuple()
TTL EventTimestamp + INTERVAL 15 MINUTE DELETE;

CREATE TABLE radacct_live
(
  AcctDate DateTime DEFAULT now() CODEC(DoubleDelta),
  AcctSessionId String,
  AcctUniqueId String,
  UserName String,
  Realm    String,
  NASIPAddress AggregateFunction(anyLastIf, Nullable(IPv6), UInt8),
  NASPortId    AggregateFunction(anyLastIf, Nullable(String), UInt8),
  NASPortType  AggregateFunction(anyLastIf, Nullable(String), UInt8),
  AcctLastStatusType AggregateFunction(argMax, String, Datetime),
  AcctStartTime AggregateFunction(min, Nullable(Datetime)),
  AcctStopTime  AggregateFunction(max, Nullable(Datetime)),
  AcctUpdateTime AggregateFunction(max, DateTime),
  AcctTerminateCause AggregateFunction(argMax, Nullable(String), Datetime),
  AcctAuthentic AggregateFunction(anyLastIf, Nullable(String), UInt8),
  ConnectInfoStart AggregateFunction(argMinIf, Nullable(String), Datetime, UInt8),
  ConnectInfoStop  AggregateFunction(argMaxIf, Nullable(String), Datetime, UInt8),
  AcctInputOctets  AggregateFunction(max, UInt64),
  AcctOutputOctets AggregateFunction(max, UInt64),
  CalledStationId  AggregateFunction(anyLastIf, Nullable(String), UInt8),
  CallingStationId AggregateFunction(anyLastIf, Nullable(String), UInt8),
  ServiceType      AggregateFunction(anyLastIf, Nullable(String), UInt8),
  FramedProtocol   AggregateFunction(anyLastIf, Nullable(String), UInt8),
  FramedIPAddress      AggregateFunction(anyLastIf, Nullable(IPv4), UInt8),
  FramedIPv6Address    AggregateFunction(anyLastIf, Nullable(IPv6), UInt8),
  FramedIPv6Prefix     AggregateFunction(anyLastIf, Nullable(IPv6), UInt8),
  FramedIPv6PrefixSize AggregateFunction(anyLastIf, Nullable(UInt8), UInt8),
  FramedInterfaceId    AggregateFunction(anyLastIf, Nullable(String), UInt8),
  DelegatedIPv6Prefix  AggregateFunction(anyLastIf, Nullable(IPv6), UInt8),
  DelegatedIPv6PrefixSize AggregateFunction(anyLastIf, Nullable(UInt8), UInt8)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(AcctDate)
ORDER BY (AcctDate, AcctSessionId, AcctUniqueId, UserName, Realm);

CREATE MATERIALIZED VIEW radacct_mv TO radacct_live AS
SELECT
  AcctSessionId,
  AcctUniqueId,
  UserName,
  Realm,
  argMaxState(AcctStatusType,  EventTimestamp) AS AcctLastStatusType,
  anyLastIfState(NASIPAddress, isNotNull(NASIPAddress)) AS NASIPAddress,
  anyLastIfState(NASPortId, isNotNull(NASPortId))    AS NASPortId,
  anyLastIfState(NASPortType, isNotNull(NASPortType))  AS NASPortType,
  minState(AcctStartTime) AS AcctStartTime,
  maxState(AcctStopTime)  AS AcctStopTime,
  maxState(EventTimestamp) AS AcctUpdateTime,
  argMaxState(AcctTerminateCause,  EventTimestamp) AS AcctTerminateCause,
  anyLastIfState(AcctAuthentic, isNotNull(AcctAuthentic)) AS AcctAuthentic,
  argMinIfState(ConnectInfoStart, EventTimestamp, AcctStatusType=='Start') AS ConnectInfoStart,
  argMaxIfState(ConnectInfoStop,  EventTimestamp, AcctStatusType=='Stop') AS ConnectInfoStop,
  maxState(AcctInputOctets)  AS AcctInputOctets,
  maxState(AcctOutputOctets) AS AcctOutputOctets,
  anyLastIfState(CalledStationId, isNotNull(CalledStationId)) AS CalledStationId,
  anyLastIfState(CallingStationId, isNotNull(CallingStationId)) AS CallingStationId,
  anyLastIfState(ServiceType, isNotNull(ServiceType)) AS ServiceType,
  anyLastIfState(FramedProtocol, isNotNull(FramedProtocol)) AS FramedProtocol,
  anyLastIfState(FramedIPAddress, isNotNull(FramedIPAddress)) AS FramedIPAddress,
  anyLastIfState(FramedIPv6Address, isNotNull(FramedIPv6Address)) AS FramedIPv6Address,
  anyLastIfState(FramedIPv6Prefix, isNotNull(FramedIPv6Prefix)) AS FramedIPv6Prefix,
  anyLastIfState(FramedIPv6PrefixSize, isNotNull(FramedIPv6PrefixSize)) AS FramedIPv6PrefixSize,
  anyLastIfState(FramedInterfaceId, isNotNull(FramedInterfaceId)) AS FramedInterfaceId,
  anyLastIfState(DelegatedIPv6Prefix, isNotNull(DelegatedIPv6Prefix)) AS DelegatedIPv6Prefix,
  anyLastIfState(DelegatedIPv6PrefixSize, isNotNull(DelegatedIPv6PrefixSize)) AS DelegatedIPv6PrefixSize
FROM radacct_raw
GROUP BY AcctSessionId, AcctUniqueId, UserName, Realm
ORDER BY AcctUpdateTime, AcctStartTime, AcctStopTime NULLS FIRST, UserName, Realm;

CREATE VIEW radacct AS
SELECT
  AcctUniqueId,
  AcctSessionId,
  UserName,
  Realm,
  anyLastIfMerge(NASIPAddress)  AS NASIPAddress,
  anyLastIfMerge(NASPortId)     AS NASPortId,
  anyLastIfMerge(NASPortType)   AS NASPortType,
  argMaxMerge(AcctLastStatusType) AS AcctLastStatusType,
  minMerge(AcctStartTime) AS AcctStartTime,
  maxMerge(AcctStopTime)  AS AcctStopTime,
  maxMerge(AcctUpdateTime) AS AcctUpdateTime,
  dateDiff('second', AcctStartTime, coalesce(AcctStopTime, now())) AS AcctSessionTime,
  argMaxMerge(AcctTerminateCause) AS AcctTerminateCause,
  anyLastIfMerge(AcctAuthentic) AS AcctAuthentic,
  argMinIfMerge(ConnectInfoStart) AS ConnectInfoStart,
  argMaxIfMerge(ConnectInfoStop) AS ConnectInfoStop,
  maxMerge(AcctInputOctets)  AS AcctInputOctets,
  maxMerge(AcctOutputOctets) AS AcctOutputOctets,
  anyLastIfMerge(CalledStationId) AS CalledStationId,
  anyLastIfMerge(CallingStationId) AS CallingStationId,
  anyLastIfMerge(ServiceType) AS ServiceType,
  anyLastIfMerge(FramedProtocol) AS FramedProtocol,
  anyLastIfMerge(FramedIPAddress) AS FramedIPAddress,
  anyLastIfMerge(FramedIPv6Address) AS FramedIPv6Address,
  anyLastIfMerge(FramedIPv6Prefix) AS FramedIPv6Prefix,
  anyLastIfMerge(FramedIPv6PrefixSize) AS FramedIPv6PrefixSize,
  anyLastIfMerge(FramedInterfaceId) AS FramedInterfaceId,
  anyLastIfMerge(DelegatedIPv6Prefix) AS DelegatedIPv6Prefix,
  anyLastIfMerge(DelegatedIPv6PrefixSize) AS DelegatedIPv6PrefixSize
FROM radacct_live
GROUP BY
  AcctSessionId,
  AcctUniqueId,
  UserName,
  Realm
ORDER BY AcctStopTime NULLS FIRST, AcctStartTime, AcctUpdateTime, AcctUniqueId;

CREATE VIEW IF NOT EXISTS radacct_active AS
SELECT DISTINCT
  FramedIPAddress,
  argMax(AcctSessionId, AcctUpdateTime) AS AcctSessionId,
  argMax(UserName, AcctUpdateTime) AS UserName,
  argMax(FramedIPv6Address, AcctUpdateTime) AS FramedIPv6Address,
  max(AcctUpdateTime) AS LastUpdate
FROM (SELECT
  AcctSessionId,
  UserName,
  maxMerge(AcctStopTime)  AS AcctStopTime,
  maxMerge(AcctUpdateTime) AS AcctUpdateTime,
  anyLastIfMerge(FramedIPAddress) AS FramedIPAddress,
  anyLastIfMerge(FramedIPv6Address) AS FramedIPv6Address
FROM radacct_live
GROUP BY
  AcctSessionId,
  UserName
ORDER BY AcctStopTime NULLS FIRST, AcctUpdateTime)
WHERE AcctStopTime IS NULL
GROUP BY FramedIPAddress;
