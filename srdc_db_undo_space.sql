REM srdc_db_undo_space.sql
REM collect Undo parameters,segment and transaction details for troubleshooting high Undo space usage issues.
define SRDCNAME='DB_Undo_Space'
set pagesize 200 verify off sqlprompt "" term off entmap off echo off
set markup html on spool on
COLUMN SRDCSPOOLNAME NOPRINT NEW_VALUE SRDCSPOOLNAME
select 'SRDC_'||upper('&&SRDCNAME')||'_'||upper(instance_name)||'_'|| to_char(sysdate,'YYYYMMDD_HH24MISS') SRDCSPOOLNAME from v$instance;
spool &&SRDCSPOOLNAME..htm
select 'Diagnostic-Name : ' "Diagnostic-Name ", '&&SRDCNAME' "Report Info" from dual
union all
select 'Time : ' , to_char(systimestamp, 'YYYY-MM-DD HH24MISS TZHTZM' ) from dual
union all
select 'Machine : ' , host_name from v$instance
union all
select 'Version : ',version from v$instance
union all
select 'DBName : ',name from v$database
union all
select 'Instance : ',instance_name from v$instance
/
set echo on

--***********************Undo Parameters**********************

SELECT a.ksppinm "Parameter",
b.ksppstvl "Session Value",
c.ksppstvl "Instance Value"
FROM sys.x$ksppi a, sys.x$ksppcv b, sys.x$ksppsv c
WHERE a.indx = b.indx
AND a.indx = c.indx
AND a.ksppinm in ( '_undo_autotune' , '_smu_debug_mode' ,
'_highthreshold_undoretention' ,
'undo_tablespace' , 'undo_retention' , 'undo_management' )
order by 2
/
--**********************Tuned Undo Retention**********************
Select max(maxquerylen),max(tuned_undoretention) from v$undostat
/
--**********************Status of the undo blocks**********************

select tablespace_name, 
round(sum(case when status = 'UNEXPIRED' then bytes else 0 end) / 1048675,2) unexpired_MB ,
round(sum(case when status = 'EXPIRED' then bytes else 0 end) / 1048576,2) expired_MB ,
round(sum(case when status = 'ACTIVE' then bytes else 0 end) / 1048576,2) active_MB 
from dba_undo_extents group by tablespace_name
/
--**********************ree space available within the Undo tablespace**********************

SELECT SUM(BYTES) FROM DBA_FREE_SPACE WHERE TABLESPACE_NAME in (select value from v$parameter where name= 'undo_tablespace')
/
SELECT file_name,autoextensible,(bytes)/(1024*1024*1024) spaceInGB,(maxbytes)/(1024*1024*1024) MaxBytesInGB FROM dba_data_files WHERE tablespace_name in (select value from v$parameter where name= 'undo_tablespace')
/
--**********************BDA related information**********************

SELECT a.ksppinm "Parameter",
b.ksppstvl "Session Value",
c.ksppstvl "Instance Value"
from sys.x$ksppi a, sys.x$ksppcv b, sys.x$ksppsv c
WHERE a.indx = b.indx
AND a.indx = c.indx
AND a.ksppinm LIKE '%flashback%' 
/
select * from dba_flashback_archive_tables
/
select * from dba_flashback_archive
/
--**********************Active and Inactive Transactions**********************

SELECT KTUXEUSN, KTUXESLT, KTUXESQN, /* Transaction ID */ KTUXESTA 
Status, KTUXECFL flags
FROM x$ktuxe WHERE ktuxesta!= 'INACTIVE' 
/
select start_time, username, r.name, ubafil, ubablk, t.status, (used_ublk*p.value)/1024 blk, used_urec from v$transaction t, v$rollname r, v$session s, v$parameter p
where xidusn=usn
and s.saddr=t.ses_addr
and p.name in (select value from v$parameter where name= 'db_block_size') 
order by 1
/
--**********************FBDA Related Information *******************************
select count(*),STATUS,INST_ID from SYS_FBA_BARRIERSCN group by STATUS,INST_ID
/


set echo off
set sqlprompt "SQL> " term on
set verify on
spool off
set markup html off spool off
set echo on