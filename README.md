# sqlite-import
  make script that imports IIS and ALB log files to a sqlite database. The script joins multiple .log files in the same folder to one file and imports it to a sqlite database
# Requirements
  - Linux subsystem installed (WSL or cmder)
  - Make installed
  - .log files located in the same path
  - makefile located in the same path as .log files
# Instructions
  1. Move this makefile to the same folder of all the .log files to be imported
  2. Open a linux command prompt (for Windows use WSL or cmder)
  3. Run "make import-iis-sqllite" or "make "import-alb-sqlite" (add option _create_indexes=true_ to create indexes in SQLite database for faster query executions)
