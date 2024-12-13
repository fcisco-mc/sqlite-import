--------- * IIS * ---------
-- TOP IPs by number of requests
SELECT COUNT(OriginalIP) AS OriginalIp_Hits, [cs_uri_stem], OriginalIP
FROM log_data
--WHERE [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY OriginalIP
ORDER BY OriginalIp_Hits DESC
LIMIT 50

-- TOP endpoints grouped by HTTP Response code 
SELECT COUNT([cs_uri_stem]) AS RequestCount, [cs_uri_stem], [sc_status]
FROM log_data
--WHERE [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY [cs_uri_stem], [sc_status]
ORDER BY RequestCount DESC
LIMIT 50

-- Request Rate per minute
SELECT [date], 
       strftime('%H:%M', [time]) AS HourMinute, -- use strftime('%H', [time]) for hourly rate
       COUNT(*) AS RequestCount
FROM log_data
-- WHERE [cs_uri_stem] = '<endpoint>'
-- AND OriginalIP = <IP>
GROUP BY [date], HourMinute
ORDER BY [date], HourMinute
LIMIT 100;

-- Endpoint average execution time per minute
SELECT [date], 
       strftime('%H:%M', [time]) AS HourMinute, -- use strftime('%H', [time]) for hourly rate
       COUNT(*) AS RequestCount,
	   [cs_uri_stem],
	   avg([time_taken]) AS AvgExecutionTime,
	   max([time_taken]) AS MaxExecutionTime
FROM log_data
-- WHERE [cs_uri_stem] = '<endpoint>'
-- AND [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY [date], HourMinute, [cs_uri_stem]
ORDER BY [date], HourMinute
LIMIT 100;

-- Request average execution with percentage change; Replace <endpoint> placeholder
WITH RequestData AS (
    SELECT 
        [date],
        strftime('%H:%M', [time]) AS HourMinute,
        COUNT(*) AS RequestCount,
        [cs_uri_stem],
        AVG([time_taken]) AS AvgExecutionTime,
        LAG(AVG([time_taken])) OVER (PARTITION BY [cs_uri_stem] ORDER BY [date], strftime('%H:%M', [time])) AS PrevAvgExecutionTime
    FROM log_Data
	WHERE [cs_uri_stem] = <endpoint> -- Replace <endpoint>
	-- AND [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
    GROUP BY [date], strftime('%H:%M', [time]), [cs_uri_stem]
	LIMIT 100
)
SELECT 
    [date],
    HourMinute,
    RequestCount,
    [cs_uri_stem],
	ROUND(AvgExecutionTime, 2) AS AvgExecutionTime,
    ROUND(PrevAvgExecutionTime, 2) AS PrevAvgExecutionTime,
    CASE 
        WHEN PrevAvgExecutionTime IS NOT NULL THEN 
            ROUND(((AvgExecutionTime - PrevAvgExecutionTime) * 100.0 / PrevAvgExecutionTime), 2)
        ELSE NULL
    END AS PercentageChange
FROM RequestData


--------- * ALB * ---------
-- TOP Client IPs by number of requests
SELECT
	CASE
		WHEN instr(client_port, ':') > 0 THEN substr(client_port, 1, instr(client_port, ':')-1)
		ELSE client_port
	END AS ClientIP,
	COUNT(client_port) AS ClientIP_RequestCount
FROM log_data
--WHERE [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY ClientIP
ORDER BY ClientIP_RequestCount DESC
LIMIT 50

-- Request count grouped by endpoint and target status code
SELECT 
    CASE 
        WHEN instr(request, '?') > 0 THEN substr(request, 1, instr(request, '?') - 1)
        ELSE request 
    END AS Endpoint,
    COUNT(request) AS RequestCount,
    target_status_code
FROM log_data
--WHERE [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY Endpoint, target_status_code
ORDER BY RequestCount DESC
LIMIT 50;

-- Requests blocked by the WAF and not forwarded to targets, grouped by client IPs
SELECT 
	CASE
		WHEN instr(client_port, ':') > 0 THEN substr(client_port, 1, instr(client_port, ':')-1)
		ELSE client_port
	END AS ClientIP,
	request,
	COUNT(request) AS RequestCount,
	actions_executed
FROM log_data
WHERE actions_executed =  '''waf'''
-- AND [date] = 'yyyy-mm-dd' AND ([time] BETWEEN 'hh:mm:ss' AND 'hh:mm:ss')
GROUP BY ClientIp
ORDER BY RequestCount DESC
LIMIT 100

-- Request Rate per minute per Target
SELECT 
	strftime('%Y-%m-%d %H:%M', substr([time], 1, 19)) AS HourMinute,  -- use strftime('%H', substr([time], 1, 19) for hourly rate
	CASE
		WHEN instr(target_port, ':') > 0 THEN substr(target_port, 1, instr(target_port, ':')-1)
		ELSE target_port
	END AS TargetServer,
	COUNT(target_port) AS RequestCount
FROM log_data
--WHERE strftime('%Y-%m-%d %H:%M', substr([time], 1, 16)) BETWEEN 'yyyy-mm-dd hh:mm' AND 'yyyy-mm-dd hh:mm'
GROUP BY HourMinute, TargetServer
ORDER BY HourMinute
LIMIT 100;

-- Request Rate per minute per ClientIP
SELECT 
	strftime('%Y-%m-%d %H:%M', substr([time], 1, 19)) AS HourMinute,  -- use strftime('%H', substr([time], 1, 19) for hourly rate
	CASE
		WHEN instr(client_port, ':') > 0 THEN substr(client_port, 1, instr(client_port, ':')-1)
		ELSE client_port
	END AS ClientIP,
	COUNT(client_port) AS RequestCount
FROM log_data
--WHERE strftime('%Y-%m-%d %H:%M', substr([time], 1, 16)) BETWEEN 'yyyy-mm-dd hh:mm' AND 'yyyy-mm-dd hh:mm'
GROUP BY HourMinute, ClientIP
ORDER BY HourMinute
LIMIT 100;

-- Request average execution times per endpoint
WITH RequestData AS (
    SELECT 
        strftime('%Y-%m-%d %H:%M', substr([time], 1, 19)) AS HourMinute,
        COUNT(*) AS RequestCount,
        CASE
			WHEN instr([request], '?') > 0 THEN substr([request], 1, instr([request], '?')-1)
			ELSE [request]
		END AS RequestEndpoint,
        AVG([request_processing_time]) AS AvgRequestProcessingTime,
        AVG([target_processing_time]) AS AvgTargetProcessingTime,
        AVG([response_processing_time]) AS AvgResponseProcessingTime        
    FROM log_Data
    WHERE [request] like '%<endpoint>%' -- Replace <endpoint>
    -- AND strftime('%Y-%m-%d %H:%M', substr([time], 1, 16)) BETWEEN 'yyyy-mm-dd hh:mm' AND 'yyyy-mm-dd hh:mm'
    GROUP BY strftime('%Y-%m-%d %H:%M', substr([time], 1, 19)), RequestEndpoint
)
SELECT 
    HourMinute,
    RequestCount,
    RequestEndpoint,
    ROUND(AvgRequestProcessingTime, 2) AS AvgRequestProcessingTime,
    ROUND(AvgTargetProcessingTime, 2) AS AvgTargetProcessingTime,
    ROUND(AvgResponseProcessingTime, 2) AS AvgResponseProcessingTime
FROM RequestData
LIMIT 100;