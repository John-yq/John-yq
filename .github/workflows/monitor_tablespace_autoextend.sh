Oracle表空间自动监控 自动扩容程序 

Oracle运维中常出现Tablespace空间满，导致挂库。

通常出现这类事件需要DBA紧急处理。

躺若DB数量上千台，表空间异常多，DBA手工排错耗时长、枯燥、易出错。

若是这类情况正好出现在半夜、周末，DBA怎一个苦字了得！

提问:有没有办法将DBA解放出来，让DB自动诊断，自动扩容表空间？

答: 用这套自动扩容脚本就好（我已多年不Coding，下午写的这套代码比较Low,仅抛砖引玉,各位大神可在此基础上改写以便更好地适应自己的DB环境）
实验环境

1.创建test_tab表，不断插入数据

declare

i int;

begin

 for i in 1..5 loop

 insert into test.test_tab select * from  test.test_tab;

 commit;

end loop;

end;

/

2.自动监控程序运行结果

Monitor tablespace and autoextend !

==================================================================================================

作者：John 杨漆

Automatically monitors the tablespace usage

Automatic capacity expansion When the tablespace usage exceeds 85%

For Oracle Database

For study and research only, shall not be used for production environment and commercial purposes

If there is any problem, please contact me on wechat john2000111

Disk usage GB显示 ！

==================================================================================================

Monitor tablespace rate Finished ！

空间使用情况

TBS_NAME                         TOTAL_GB    USED_GB    FREE_GB RATE    MAXEXTEND_GB

------------------------------ ---------- ---------- ---------- ------- ------------

TEST                                    2       1.25        .75   62.50            2

DS_DATA                              4.67       2.54       2.13    1.98          128

SYSAUX                                .55        .52        .03    1.63           32

SYSTEM                               1.73        .73          1    1.14           64

USERS                                 .09          0        .09    0.00           32

TEST表空间使用率超过60% （为方便实验环境自动扩展阈值设为60%）

3.查询数据文件情况

select name from v$datafile;

NAME

-------------------------------------------

/u01/app/oracle/oradata/orcl/system01.dbf

/u01/app/oracle/oradata/orcl/sysaux01.dbf

/u01/app/oracle/oradata/orcl/undotbs01.dbf

/u01/app/oracle/oradata/orcl/users01.dbf

/u01/app/oracle/oradata/orcl/DS_DATA01.dbf

/u01/app/oracle/oradata/orcl/DS_DATA02.dbf

/u01/app/oracle/oradata/orcl/SYSTEM1

/u01/app/oracle/oradata/orcl/DS_DATA03.dbf

/u01/app/oracle/oradata/orcl/DS_DATA04.dbf

/u01/app/oracle/oradata/orcl/test01.dbf

/u01/app/oracle/oradata/orcl/TEST02.dbf

4.调用自动诊断、扩容程序（实验手动调用，正式使用时放在Job里自动调用）

SQL> exec proc_monitor_tbs_rate;

thanks for you to use Tablespace Automatic extension program !

The author: John 杨漆

TEST add TEST03.dbf

Tablespace Automatic extension succeeded

5.再次查询空间使用情况

TBS_NAME                         TOTAL_GB    USED_GB    FREE_GB RATE    MAXEXTEND_GB

------------------------------ ---------- ---------- ---------- ------- ------------

TEST                                    3       1.25       1.75   41.67            3

DS_DATA                              4.67       2.54       2.13    1.98          128

SYSAUX                                .55        .52        .03    1.63           32

SYSTEM                               1.73        .73          1    1.14           64

USERS                                 .09          0        .09    0.00           32

使用率已从62.5% 降到41.67%

6.再次查询数据文件情况

select name from v$datafile;

NAME

-------------------------------------------

/u01/app/oracle/oradata/orcl/system01.dbf

/u01/app/oracle/oradata/orcl/sysaux01.dbf

/u01/app/oracle/oradata/orcl/undotbs01.dbf

/u01/app/oracle/oradata/orcl/users01.dbf

/u01/app/oracle/oradata/orcl/DS_DATA01.dbf

/u01/app/oracle/oradata/orcl/DS_DATA02.dbf

/u01/app/oracle/oradata/orcl/SYSTEM1

/u01/app/oracle/oradata/orcl/DS_DATA03.dbf

/u01/app/oracle/oradata/orcl/DS_DATA04.dbf

/u01/app/oracle/oradata/orcl/test01.dbf

/u01/app/oracle/oradata/orcl/TEST02.dbf

/u01/app/oracle/oradata/orcl/TEST03.dbf

增加了一个 TEST03,自动扩容成功！

-- Oracle表空间自动监控 自动扩容程序 修订版

## 放在OS定时任务里,每30分钟自动运行一次，监控DB表空间使用状况

vi monitor_tablespace_autoextend.sh

#!/bin/bash

echo " Monitor tablespace and autoextend !"

echo "=================================================================================================="

echo " 作者：John 杨漆"

echo " Automatically monitors the tablespace usage "

echo " Automatic capacity expansion When the tablespace usage exceeds 85% "

echo " For Oracle Database"

echo " For study and research only, shall not be used for production environment and commercial purposes"

echo " If there is any problem, please contact me on wechat john2000111"

echo " Disk usage GB显示 ！"

echo "=================================================================================================="

source ~/.bash_profile

sqlplus -S "/ as sysdba" <<EOF

set linesize 400

set pagesize 200

set feed off

truncate table monitor_tablespace_rate;

insert into  monitor_tablespace_rate select * from

(SELECT D.TABLESPACE_NAME                TBS_NAME,

      D.TOT_GROOTTE_MB                 TOTAL_GB,

      D.TOT_GROOTTE_MB - F.TOTAL_BYTES USED_GB,

      F.TOTAL_BYTES                    FREE_GB,

      TO_CHAR(ROUND((D.TOT_GROOTTE_MB - F.TOTAL_BYTES) / D.MAXEXTEND_MB * 100,2),'990.99')        RATE,

      D.MAXEXTEND_MB                   MAXEXTEND_GB

 FROM (SELECT TABLESPACE_NAME,

              Round(Sum(NVL(BYTES,0)) / (1024 * 1024 * 1024), 2) TOTAL_BYTES,

              Round(Max(NVL(BYTES,0)) / (1024 * 1024 * 1024), 2) MAX_BYTES

         FROM SYS.DBA_FREE_SPACE

        GROUP BY TABLESPACE_NAME) F,

      (SELECT DD.TABLESPACE_NAME,

              Round(Sum(DD.BYTES) / (1024 * 1024 * 1024), 2) TOT_GROOTTE_MB,

              Round(Sum(DECODE(DD.MAXBYTES,0,DD.BYTES,DD.MAXBYTES)) / (1024 * 1024 * 1024), 2) MAXEXTEND_MB

         FROM SYS.DBA_DATA_FILES DD

        GROUP BY DD.TABLESPACE_NAME) D

WHERE D.TABLESPACE_NAME = F.TABLESPACE_NAME(+)

AND   D.TABLESPACE_NAME NOT LIKE '%UNDO%'

ORDER BY 5 desc);

exit

EOF

echo " Monitor tablespace rate Finished ！"

## 以下部分仅需在DB端执行一遍

-- 创建监控表

 CREATE TABLE "SYS"."MONITOR_TABLESPACE_RATE"

  (    "TBS_NAME" VARCHAR2(50),

       "TOTAL_GB" NUMBER,

       "USED_GB" NUMBER,

       "FREE_GB" NUMBER,

       "RATE" NUMBER,

       "MAXEXTEND_GB" NUMBER

  );

-- 创建存储过程，可用剩余空间小于15%时自动扩容tablespace

set serveroutput on;

create or replace procedure proc_monitor_tbs_rate

as

file_num int;

file_name varchar2(200);

new_file_name varchar2(200);

str varchar2(300) ;

begin

 dbms_output.put_line('thanks for you to use Tablespace Automatic extension program ! ');

 dbms_output.put_line('The author: John 杨漆 ');  

 for i in (select TBS_NAME,RATE from monitor_tablespace_rate) loop

     if i.rate>85 then

       select count(file_id) into file_num from dba_data_files where tablespace_name=i.TBS_NAME;

       file_num := file_num + 1;

       select file_name  into file_name  from dba_data_files where tablespace_name=i.TBS_NAME and rownum=1;

       new_file_name :=substr(file_name,1,instr(file_name,'/',-1))||i.TBS_NAME||'0'||file_num||'.dbf';

       str :='alter tablespace '||i.TBS_NAME||' add datafile '||''''||new_file_name||''''|| ' size 1G autoextend on';

       execute immediate str;

       DBMS_OUTPUT.PUT_LINE(i.TBS_NAME||' add '||new_file_name);

     end if;

 end loop;

 dbms_output.put_line('Tablespace Automatic extension succeeded ');

end;

/

-- 创建定时任务，每小时执行一次  (存储过程里的;号不能省略)

variable jobno number;

begin

dbms_job.submit(:jobno,'proc_monitor_tbs_rate;', sysdate, 'sysdate+1/24');

commit;

end;

/

-- 查看定时任务情况

select job, next_date, next_sec, failures, broken from user_jobs;

      JOB NEXT_DATE          NEXT_SEC                           FAILURES B

---------- ------------------ -------------------------------- ---------- -

        3 23-JUL-21          14:57:06                                  0 N

-- 任务生成成功，Job号为3

-- 停止定时任务

begin

dbms_job.broken(3, true, sysdate);

commit;

end;

/

-- 启动定时任务

begin

dbms_job.run(3);

commit;

end;

/

## 查看手工编写的存储过程内容

select text from dba_source where name=upper('proc_monitor_tbs_rate');

## 查看表所占空间大小

select SEGMENT_NAME,sum(BYTES)/1024/1024 M from dba_segments where SEGMENT_NAME='TEST_TAB' group by SEGMENT_NAME;
