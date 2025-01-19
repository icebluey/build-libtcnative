Tomcat 8.5 requires Java 7 or later.\
Tomcat 9.0 requires Java 8 or later.\
Tomcat 10.1 requires Java 11 or later.\
Tomcat Native 2 for Tomcat 9 or later.\
Tomcat Native 1.2 for Tomcat 8 and 9

```
Tomcat Native 2.0.X:
the minimum required version of OpenSSL to 3.0
the minimum required version of APR to 1.7
the minimum required Java version to Java 11
```

# server.xml

```
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
```

```
# tomcat v8.5, v9.0, using tomcat native 1.x
# type="RSA" or type="EC"

    <Connector port="80" protocol="org.apache.coyote.http11.Http11AprProtocol"
               connectionTimeout="20000" redirectPort="443" />
    <Connector port="443" protocol="org.apache.coyote.http11.Http11AprProtocol"
               maxThreads="300" SSLEnabled="true" scheme="https" secure="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig protocols="TLSv1.3+TLSv1.2" >
            <Certificate certificateKeyFile="keys/server.key"
                         certificateFile="keys/server.crt"
                         certificateChainFile="keys/fullchain.crt"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>



# tomcat v10.1, using tomcat native 2.x
# type="RSA" or type="EC"

    <Connector port="80" protocol="org.apache.coyote.http11.Http11Nio2Protocol"
               connectionTimeout="20000" redirectPort="443" />
    <Connector port="443" protocol="org.apache.coyote.http11.Http11Nio2Protocol"
               maxThreads="300" SSLEnabled="true" scheme="https" secure="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig protocols="TLSv1.3+TLSv1.2" >
            <Certificate certificateKeyFile="keys/server.key"
                         certificateFile="keys/server.crt"
                         certificateChainFile="keys/fullchain.crt"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>

```

# setenv.sh
```bin/setenv.sh```
```
LD_LIBRARY_PATH=/usr/local/tomcat-native:$LD_LIBRARY_PATH:$CATALINA_HOME/lib
export LD_LIBRARY_PATH
```

# Java
```
ubuntu: /etc/bash.bashrc
rhel: /etc/bashrc
```
```
JAVA_HOME=/usr/java/jdk
export JAVA_HOME
PATH=$JAVA_HOME/bin:$PATH
export PATH
#CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
if [ -f $JAVA_HOME/jre/lib/rt.jar ]; then CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar; else CLASSPATH=.; fi
export CLASSPATH
```

# redirect 301
Insert a line below ```<Engine name="Catalina" defaultHost="localhost">``` in server.xml
```
<Realm className="org.apache.catalina.realm.LockOutRealm" transportGuaranteeRedirectStatus="301">
```
Add to web.xml above last line ```</web-app>```

```
    <security-constraint>
        <web-resource-collection>
            <web-resource-name>SSL</web-resource-name>
            <url-pattern>/*</url-pattern>
        </web-resource-collection>
        <user-data-constraint>
            <transport-guarantee>CONFIDENTIAL</transport-guarantee>
        </user-data-constraint>
    </security-constraint>
```

```
#save configuration permanently
echo 'net.ipv4.ip_unprivileged_port_start=0' > /etc/sysctl.d/50-unprivileged-ports.conf
#apply conf
sysctl --system


getent group tomcat >/dev/null || groupadd -r tomcat
getent passwd tomcat >/dev/null || useradd -r -d /opt/tomcat \
  -g tomcat -s /usr/sbin/nologin -c "Apache Tomcat" tomcat

chown -R tomcat:tomcat /opt/tomcat

/bin/su -s /bin/bash -c "/opt/tomcat/bin/startup.sh" tomcat

```

```
CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'

-Xms512M：设置 Java 虚拟机的初始内存分配池大小为 512MB。Tomcat 启动时会分配这个内存大小。
-Xmx1024M：设置 Java 虚拟机的最大内存分配池大小为 1024MB。当应用程序需要更多内存时，JVM 可以增长到这个限制。
-server：指定 JVM 以服务器模式运行，这通常会提升性能。对于生产环境来说是推荐的设置。
-XX:+UseParallelGC：启用并行垃圾回收器（Parallel GC），会使用多个线程进行垃圾回收，适合 CPU 核心较多的系统。

```
