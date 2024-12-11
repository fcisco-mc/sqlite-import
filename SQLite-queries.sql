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