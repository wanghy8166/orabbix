# 依赖的镜像
FROM centos:7.3.1611
# 安装必要路径
RUN mkdir -p /opt/orabbix/
WORKDIR /opt/orabbix
# 设置环境变量
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV JAVA_HOME /opt/orabbix/jre1.6.0_45
ENV CLASSPATH .:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
ENV PATH $JAVA_HOME/bin:$PATH
# 设置时间
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone
# 添加本地文件到容器中,如果是压缩包会在目标目录进行自动解压
ADD orabbix-1.2.3.tar.gz /opt/orabbix/
# ADD jdk-6u45-linux-x64.tar.gz /opt/orabbix/
ADD jre-6u45-linux-x64.bin /opt/orabbix/ 
RUN sh jre-6u45-linux-x64.bin && rm -rf jre-6u45-linux-x64.bin 
# ADD config.props /opt/orabbix/ 
# RUN mv /opt/orabbix/config.props /opt/orabbix/conf/
# RUN chmod -R a+x /opt/orabbix/
# 容器启动命令
ENTRYPOINT /opt/orabbix/run.sh && tail -F /opt/orabbix/logs/orabbix.log
