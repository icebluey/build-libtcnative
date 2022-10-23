# server.xml
## http
```

    <Connector port="80" protocol="org.apache.coyote.http11.Http11AprProtocol"
               connectionTimeout="20000"
               redirectPort="443" />

```

## https
```

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

```
