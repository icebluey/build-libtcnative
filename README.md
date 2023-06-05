
Tomcat Native 2 for Tomcat 10.1.x \
Tomcat Native 1.2 for Tomcat 8 and 9

# server.xml

```
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
```

```
# tomcat v8.5, v9.0

    <Connector port="80" protocol="org.apache.coyote.http11.Http11AprProtocol"
               connectionTimeout="20000"
               redirectPort="443" />

    <Connector port="443" protocol="org.apache.coyote.http11.Http11AprProtocol"
               maxThreads="300" SSLEnabled="true" scheme="https" secure="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig protocols="TLSv1.3+TLSv1.2" >
        <Certificate certificateKeyFile="keys/domain.key"
            certificateFile="keys/domain.crt"
            certificateChainFile="keys/fullchain.crt"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>

# tomcat v10.1

    <Connector port="80" protocol="org.apache.coyote.http11.Http11Nio2Protocol"
               connectionTimeout="20000"
               redirectPort="443" />

    <Connector port="443" protocol="org.apache.coyote.http11.Http11Nio2Protocol"
               maxThreads="300" SSLEnabled="true" scheme="https" secure="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig protocols="TLSv1.3+TLSv1.2" >
        <Certificate certificateKeyFile="keys/domain.key"
            certificateFile="keys/domain.crt"
            certificateChainFile="keys/fullchain.crt"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>

```

# setenv.sh
```bin/setenv.sh```
```
LD_LIBRARY_PATH=/path/to/lib:$LD_LIBRARY_PATH:$CATALINA_HOME/lib
export LD_LIBRARY_PATH
```

# Java
```/etc/profile.d/java.sh```
```
JAVA_HOME=/usr/java/jdk
export JAVA_HOME
PATH=$JAVA_HOME/bin:$PATH
export PATH
CLASSPATH=.:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
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
