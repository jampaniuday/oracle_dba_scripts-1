---截止某个快照点指定模块的SQL运行情况


SELECT HASH_VALUE,
       ROUND(CPU_TIME / 1000000, 0) CPU_TIME,
       ROUND(SUM(CPU_TIME) OVER() / 1000000) TOTAL_CPU,
       ROUND(CPU_TIME / SUM(CPU_TIME) OVER() * 100, 0) PERF,
       EXECUTIONS,
       ROUND(AVG_CPU / 1000000, 2) AVG_CPU,
       ROUND(AVG_DISK, 0) AVG_DISK,
       (SELECT TO_CHAR(PERFSTAT.STRING_AGG(SQL_TEXT))
          FROM PERFSTAT.STATS$SQLTEXT E
         WHERE HASH_VALUE = C.HASH_VALUE) SQL_TEXT
  FROM (SELECT /*+PARALLEL(a,48) parallel(b,48)*/
         B.HASH_VALUE,
         B.CPU_TIME - NVL(DECODE(SIGN(A.CPU_TIME), -1, 0, A.CPU_TIME), 0) CPU_TIME,
         B.EXECUTIONS -
         NVL(DECODE(SIGN(A.EXECUTIONS), -1, 0, A.EXECUTIONS), 0) EXECUTIONS,
         (B.CPU_TIME - A.CPU_TIME) /
         DECODE(B.EXECUTIONS - A.EXECUTIONS,
                0,
                NULL,
                B.EXECUTIONS - A.EXECUTIONS) AVG_CPU,
         (B.BUFFER_GETS - A.BUFFER_GETS) /
         DECODE(B.EXECUTIONS - A.EXECUTIONS,
                0,
                NULL,
                B.EXECUTIONS - A.EXECUTIONS) AVG_DISK
          FROM (SELECT *
                  FROM PERFSTAT.STATS$SQL_SUMMARY B
                 WHERE B.SNAP_ID = &END_SNAPID
                   AND NVL(B.MODULE, 'Null') LIKE '&program%'
                   AND B.CPU_TIME > 0) B
          LEFT OUTER JOIN (SELECT *
                            FROM PERFSTAT.STATS$SQL_SUMMARY A
                           WHERE A.SNAP_ID = &END_SNAPID - 1
                             AND NVL(A.MODULE, 'Null') LIKE '&program%'
                             AND A.CPU_TIME > 0) A
            ON A.HASH_VALUE = B.HASH_VALUE
           AND B.CPU_TIME >= A.CPU_TIME) C
 ORDER BY 4 DESC
