import ballerina/crypto;
import ballerina/log;
import ballerina/os;
import ballerinax/kafka;

final kafka:SecureSocket & readonly secureSocketConfig = {
    cert: getCertConfig().cloneReadOnly(),
    protocol: {
        name: kafka:SSL
    },
    'key: check getKeystoreConfig().cloneReadOnly()
};

isolated function getCertConfig() returns crypto:TrustStore|string {
    crypto:TrustStore|string cert = kafkaMtlsConfig.cert;
    if cert is string {
        return cert;
    }
    string trustStorePassword = os:getEnv("TRUSTSTORE_PASSWORD") == "" ? cert.password : os:getEnv("TRUSTSTORE_PASSWORD");
    string trustStorePath = getFilePath(cert.path, "TRUSTSTORE_FILE_NAME");
    log:printDebug("Kafka client SSL truststore configuration: ", path = trustStorePath);
    return {
        path: trustStorePath,
        password: trustStorePassword
    };
}

isolated function getKeystoreConfig() returns record {|crypto:KeyStore keyStore; string keyPassword?;|}|kafka:CertKey|error? {
    if kafkaMtlsConfig.key is () {
        return;
    }
    if kafkaMtlsConfig.key is kafka:CertKey {
        return kafkaMtlsConfig.key;
    }
    record {|crypto:KeyStore keyStore; string keyPassword?;|} 'key = check kafkaMtlsConfig.key.ensureType();
    string keyStorePassword = os:getEnv("KEYSTORE_PASSWORD") == "" ? 'key.keyStore.password : os:getEnv("KEYSTORE_PASSWORD");
    string keyStorePath = getFilePath('key.keyStore.path, "KEYSTORE_FILE_NAME");
    log:printDebug("Kafka client SSL keystore configuration: ", path = keyStorePath);
    return {
        keyStore: {
            path: keyStorePath,
            password: keyStorePassword
        },
        keyPassword: 'key.keyPassword
    };
}

isolated function getFilePath(string defaultFilePath, string envVariableName) returns string {
    string trustStoreFileName = os:getEnv(envVariableName);
    if trustStoreFileName == "" {
        return defaultFilePath;
    }
    return string `/home/ballerina/resources/brokercerts/${trustStoreFileName}`;
}

kafka:ProducerConfiguration statePersistConfig = {
    clientId: "state-persist",
    acks: "1",
    retryCount: 3,
    secureSocket: secureSocketConfig,
    securityProtocol: kafka:PROTOCOL_SSL
};
final kafka:Producer statePersistProducer = check new (kafkaUrl, statePersistConfig);
