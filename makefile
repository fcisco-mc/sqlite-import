# Makefile to import IIS and ALB logs to a SQLite database
# Requirements:
#	- Linux subsystem installed (WSL or cmder)
#	- Make installed
#	- .log files located in the same path
#	- makefile located in the same path as .log files
# Instructions:
#	1. Move this makefile to the same folder of all the .log files to be imported
#	2. Open a linux command prompt (for Windows use WSL or cmder)
#	3. Run "make import-iis-sqllite" or "make "import-alb-sqlite"

# Variables
db-name = database.db
table-name = log_data
csv-file = Output.csv
sanitized-csv-file = Sanitized.csv

#1 Full command to import multiple IIS logs into a sqlite database
import-iis-sqlite: merge-iis-csv create-iis-sqlite-db import-iis-logs-sqlite clean
	@echo "IIS logs to SQLite database import complete. Database is available in file $(db-name)"
	
#2 Full command to import multiple AWS ALB logs into a sqlite database
import-alb-sqlite: merge-alb-csv create-alb-sqlite-db preprocess-alb-logs import-alb-logs-sqlite clean
	@echo "ALB logs to SQLite database import complete. Database is available in file $(db-name)"

# Condense multiple IIS logs in one csv file
merge-iis-csv:
	@echo "Starting merge of IIS logs..."
	@head -4 $$(ls *.log | head -1) | tail -1 | sed 's/#Fields: //' > Output.csv
	@tail -n +5 -q *.log  >> Output.csv
	@echo "Merge finished"
	
# Create sqlite database and table with IIS logs column names - adapt table definition if using different columns
create-iis-sqlite-db:
	@echo "Creating table $(table-name) in database $(db-name)..."
	@echo "CREATE TABLE IF NOT EXISTS $(table-name) ( \
		date TEXT, \
		time TEXT, \
		s_ip TEXT, \
		cs_method TEXT, \
		cs_uri_stem TEXT, \
		cs_uri_query TEXT, \
		s_port INTEGER, \
		cs_username TEXT, \
		c_ip TEXT, \
		cs_User_Agent TEXT, \
		cs_Referer TEXT, \
		sc_status INTEGER, \
		sc_substatus INTEGER, \
		sc_win32_status INTEGER, \
		sc_bytes INTEGER, \
		cs_bytes INTEGER, \
		time_taken INTEGER, \
		OriginalIP TEXT \
	);" > create_table.sql
	@sqlite3 $(db-name) < create_table.sql
	@rm create_table.sql
	@echo "Database $(db-name) and table $(table-name) created successfully"

# Import csv file to sqlite database
import-iis-logs-sqlite:
	@echo "Importing logs data into sqlite table..."
	#sed is used to saninitize the records - " is replaced by ' to avoid unescaped character errors when importing to sqlite
	@sed "s/\"/'/g" $(csv-file) > $(sanitized-csv-file)
	@sqlite3 $(db-name) ".mode csv" ".separator \" \"" ".import $(sanitized-csv-file) $(table-name)"
	@echo "Import complete"
	
clean:
	@echo "Cleaning up files..."
	@rm -f $(csv-file)
	@rm -f $(sanitized-csv-file)
	@echo "Clean-up complete"
	
clean-db:
	@echo "Cleaning up sqlite database..."
	@rm -f $(db-name)
	@echo "Database file deleted"

# Condense LB logs into one csv file
merge-alb-csv:
	@echo "Starting merge of LB logs..."
	@tail -n +0 -q *.log  >> $(csv-file)
	@echo "Merge finished"
	
# Create sqlite database and table with AWS ALB logs column names - adapt table definition if using different columns
create-alb-sqlite-db:
	@echo "Creating table $(table-name) in database $(db-name)..."
	@echo "CREATE TABLE IF NOT EXISTS $(table-name) ( \
	    type TEXT, \
	    time TEXT, \
	    elb TEXT, \
	    client_port TEXT, \
	    target_port TEXT, \
	    request_processing_time REAL, \
	    target_processing_time REAL, \
	    response_processing_time REAL, \
	    elb_status_code INTEGER, \
	    target_status_code INTEGER, \
	    received_bytes INTEGER, \
	    sent_bytes INTEGER, \
	    request TEXT, \
	    user_agent TEXT, \
	    ssl_cipher TEXT, \
	    ssl_protocol TEXT, \
	    target_group_arn TEXT, \
	    trace_id TEXT, \
	    domain_name TEXT, \
	    chosen_cert_arn TEXT, \
	    matched_rule_priority INTEGER, \
	    request_creation_time TEXT, \
	    actions_executed TEXT, \
	    redirect_url TEXT, \
	    lambda_error_reason TEXT, \
	    target_port_list TEXT, \
	    target_status_code_list TEXT, \
	    classification TEXT, \
	    classification_reason TEXT \
	);" > create_table.sql
	@sqlite3 $(db-name) < create_table.sql
	@rm create_table.sql
	@echo "Database $(db-name) and table $(table-name) created successfully."
	
preprocess-alb-logs:
# Process the csv file to replace spaces with commas (,). If the chars are within double quotes, replace only , by ;. Else, print char
	@echo "Preprocessing ALB logs..."
	@awk 'BEGIN {in_quotes=0} \
	{ \
		for (i = 1; i <= length($$0); i++) { \
			char = substr($$0, i, 1); \
			if (char == "\"") { \
				in_quotes = !in_quotes; \
				printf "\047"; \
			} else if (char == " " && !in_quotes) { \
				printf ","; \
			} else if (char == "," && in_quotes) { \
				printf ";"; \
			} else { \
				printf "%s", char; \
			} \
		} \
		printf "\n"; \
	}' $(csv-file) > $(sanitized-csv-file)

	@echo "Processing complete"
	
import-alb-logs-sqlite:
	@echo "Importing ALB logs data into sqlite table..."
	@sqlite3 $(db-name) ".mode csv" ".separator \",\"" ".import $(sanitized-csv-file) $(table-name)"
	@echo "Import complete"