oracle技术预研-分布式查询

测试环境:
CentOS Linux release 7.4.1708 (Core) 
Oracle 11.2.0.4.161018 (24006111)，单机实例2个:orcl01,orcl02
# http://dl.mycat.io/
Mycat-server-1.6.7.1-release-20190213150257-linux.tar.gz
# https://www.oracle.com/technetwork/java/javase/downloads/index.html
jre-8u202-linux-x64.tar.gz

oracle实例orcl01,orcl02建用户
export ORACLE_SID="orcl01"
export ORACLE_SID="orcl02"
sqlplus / as sysdba
--drop user query cascade;
create user query identified by "123456"
  default tablespace users
  temporary tablespace TEMP
  profile DEFAULT;
--为了方便测试，授权dba
grant dba to query;

oracle实例orcl01建表
sqlplus query/123456@//127.0.0.1:1521/orcl01
create table province(id int,name varchar(30));
truncate table province;
insert into  province(id,name)values(1001,'Anhui');
insert into  province(id,name)values(1002,'Beijing');
commit;
select * from province;
create table customer(id int primary key,name varchar(30));
truncate table customer;
insert into customer(id,name) values(1001,'1a');
insert into customer(id,name) values(1002,'1b');
commit;
select * from customer;

oracle实例orcl02建表
sqlplus query/123456@//127.0.0.1:1521/orcl02
create table province(id int,name varchar(30));
truncate table province;
insert into  province(id,name)values(2001,'Chongqing');
insert into  province(id,name)values(2002,'Fujian');
commit;
select * from province;
create table customer(id int primary key,name varchar(30));
truncate table customer;
insert into customer(id,name) values(2001,'2a');
insert into customer(id,name) values(2002,'2b');
commit;
select * from customer;

mycat环境配置
mkdir -p /opt/mycat
cd /opt/mycat
tar zxvf jre-8u202-linux-x64.tar.gz
tar zxvf Mycat-server-1.6.7.1-release-20190213150257-linux.tar.gz
#添加日志目录
mkdir -p mycat/logs
cat >>/root/.bash_profile<<EOF
export MYCAT_HOME=/opt/mycat/mycat
export  JAVA_HOME=/opt/mycat/jre1.8.0_202
PATH=$PATH:$MYCAT_HOME/bin:$JAVA_HOME/bin
export PATH
EOF

为了让mycat连接到后端的oracle，需要用到ojdbc6.jar
cp /opt/app/oracle/product/11.2.0/db_1/jdbc/lib/ojdbc6.jar /opt/mycat/mycat/lib/ojdbc6.jar

为了使分片join的count(1)准确，修改useOffHeapForMerge的值为0 
cat /opt/mycat/mycat/conf/server.xml|grep -in useOffHeapForMerge

为了让mycat连接到后端的oracle，需要修改schema.xml
mv /opt/mycat/mycat/conf/schema.xml /opt/mycat/mycat/conf/schema.xml-`date +%Y%m%d-%H%M%S`
cat >/opt/mycat/mycat/conf/schema.xml<<EOF
<?xml version="1.0"?>
<!DOCTYPE mycat:schema SYSTEM "schema.dtd">
<mycat:schema xmlns:mycat="http://io.mycat/">

        <schema name="TESTDB" checkSQLschema="false" sqlMaxLimit="10000000">
            <table name="province" dataNode="dn1,dn2,dn3" rule="auto-sharding-long" />
            <table name="customer" dataNode="dn1,dn2,dn3" rule="auto-sharding-long" />
        </schema>

        <dataNode name="dn1" dataHost="oracle1" database="query" />
        <dataNode name="dn2" dataHost="oracle2" database="query" />
        <dataNode name="dn3" dataHost="oracle2" database="query" />

        <dataHost name="oracle1" maxCon="1000" minCon="1" balance="0" writeType="0"   dbType="oracle" dbDriver="jdbc"> 
            <heartbeat>select 1 from dual</heartbeat>
            <connectionInitSql>alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss'</connectionInitSql>
            <writeHost host="hostM1" url="jdbc:oracle:thin:@127.0.0.1:1521:orcl01" user="query"       password="123456" > </writeHost> 
        </dataHost>

        <dataHost name="oracle2" maxCon="1000" minCon="1" balance="0" writeType="0"   dbType="oracle" dbDriver="jdbc"> 
            <heartbeat>select 1 from dual</heartbeat>
            <connectionInitSql>alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss'</connectionInitSql>
            <writeHost host="hostM1" url="jdbc:oracle:thin:@127.0.0.1:1521:orcl02" user="query"       password="123456" > </writeHost> 
        </dataHost>

</mycat:schema>
EOF

启动mycat服务
mycat stop
mycat start

观察启动日志
tail -F /opt/mycat/mycat/logs/wrapper.log
tail -F /opt/mycat/mycat/logs/mycat.log

安装mysql客户端
yum install mysql

连接到mycat
mysql -h127.0.0.1 -P8066 -uroot -p123456 --database=TESTDB
mysql -h127.0.0.1 -P8066 -uuser -puser --database=TESTDB
select a.*,b.* from province a,customer b  where a.id=b.id order by a.id;

mycat分片join查询示例:
MySQL [TESTDB]> select a.*,b.* from province a,customer b  where a.id=b.id order by a.id;
+------+-----------+------+------+
| ID   | NAME      | ID   | NAME |
+------+-----------+------+------+
| 1001 | Anhui     | 1001 | 1a   |
| 1002 | Beijing   | 1002 | 1b   |
| 2001 | Chongqing | 2001 | 2a   |
| 2001 | Chongqing | 2001 | 2a   |
| 2002 | Fujian    | 2002 | 2b   |
| 2002 | Fujian    | 2002 | 2b   |
+------+-----------+------+------+
6 rows in set (0.02 sec)

MySQL [TESTDB]> 

尝试使用oci、ojdbc6.jar驱动连接到mycat
mycat =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.0.125)(PORT = 8066))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = TESTDB)
    )
  )
java.exe -jar CardEncrypt.jar
jdbc:oracle:thin:@192.168.0.125:8066:TESTDB

tnsping mycat提示,sqlplus登录mycat提示,pl/sql登录mycat提示,都是:
TNS-12569: TNS:packet checksum failure

ojdbc6.jar连接mycat提示:
Size Data Unit (sdu) mismatch

后来得知:
连接MyCAT需要使用MySQL驱动及协议，连接成功后可以使用Oracle语法的SQL语句进行操作。但是毕竟MySQL和Oracle还是不同的，所以会有很多坑。

参见:
Mycat适配oracle，各种坑
https://cloud.tencent.com/developer/article/1047893
MyCat做Oracle分布式中间件，报错
https://github.com/MyCATApache/Mycat-Server/issues/2141

小结，对于我们实际需求，2个方案:
1、不使用mycat
    如果要查历史，需要切换登录不同的oracle库；
2、测试后使用mycat
    可以改用jdbc(mysql驱动源)连接mycat做测试，主要功能通过后再使用。