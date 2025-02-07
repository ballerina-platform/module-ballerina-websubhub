# [Kafka Websubhub] Helm charts

Ballerina Kafka Websubhub is a WebSub compliant `hub` implementation backed by Apache Kafka message broker.

[Overview of Kafka Websubhub](https://github.com/ballerina-platform/module-ballerina-websubhub/blob/kafkahub-mtls/examples/kafka-hub/A%20Guide%20on%20implementing%20Websub%20Hub%20backed%20by%20Kafka%20Message%20Broker.md)

## Introduction

These charts bootstrap a [Kafka Websubhub](https://github.com/ballerina-platform/module-ballerina-websubhub/blob/kafkahub-mtls/examples/kafka-hub) deployment 
on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

The **Kafka Websubhub** setup contains two separate components:
- **`hub`** : A WebSub compliant `hub` implementation
- **`consolidator`** : A backend service which manages the overall deployment state

## Prerequisites

- Kubernetes 1.32+
- Helm 3.17.0+

## Deployment

### 1. Deploying the `hub`

Helm charts related to the `hub` component can be found in the `hub` directory. 

To install the charts with the release name `ballerina-websubhub`, go into the `hub` directory and run the following command:

```sh
    $ cd hub
    $ helm install ballerina-websubhub .
```

To uninstall/delete the `ballerina-websubhub` statefulset, run the following command:

```sh
    $ helm delete ballerina-websubhub
```

#### Configurations

The Kafka Websubhub container image related configurations can be found under `deployment.image` in the `hub/values.yaml`.

| Configuration  | Description                        |
|-------------- |-------------------------------------|
| `repository`  | Image repository.                   |
| `pullPolicy`  | Image pull policy for the deployment|
| `tag`         | Image tag                           |


All the package related configurations can be found under `deployment.config` in the `hub/values.yaml`. 

Following are a list of configurations and their usage.

| Configuration               | Description                                                                     |
|-----------------------------|---------------------------------------------------------------------------------|
| `port`                      | The port that is used to start the hub                                          |
| `server_id`                 | Server ID is used to uniquely identify each server                              |
| `state_snapshot_endpoint`   | Consolidator HTTP endpoint to retrieve the current state snapshot               |
| `retryable_status_codes`    | The HTTP status codes for which the client should retry during message delivery |
| `logLevel`                  | The package log level                                                           |
| `ssl.keystore_name`         | The name of the Java keystore file used to enable HTTPS on `hub`                |
| `ssl.keystore_password`     | The password for the Java keystore file                                         |
| `idp.jwt_issuer`            | The `issuer` claim for OAuth2 (JWT) token                                       |
| `idp.jwt_audience`          | The `audience` claim for OAuth2 (JWT) token                                     |
| `idp.jwt_jwks_endpoint`     | The JWKS endpoint URL to verify the JWT signature                               |
| `idp.truststore_name`       | The client truststore file name used for JWKS connection                        |
| `idp.truststore_password`   | The client truststore password                                                  |
| `kafka.bootstrap_node`      | IP and port of the Kafka bootstrap node                                         |
| `kafka.max_poll_records`    | Maximum number of records returned in a single call to consumer-poll            |
| `kafka.truststore_name`     | The client truststore file name used for mTLS connection from `hub` to `broker` |
| `kafka.truststore_password` | The client truststore password                                                  |
| `kafka.keystore_name`       | The client keystore file name used for mTLS connection from `hub` to `broker`   |
| `kafka.keystore_password`   | The client keystore password                                                    |

#### Volume mounts

Apart from the above configurations, several volume mounts are required for the deployment. All volume mounts are Kubernetes secrets, and they are listed under `deployment.secrets` in `hub/values.yaml`.  

Each secret follows the structure below:  

- **`name`**: Name of the secret
- **`mountPath`**: The path on the pod where the secrets should be mounted  
- **`content`**: A list of secrets to be mounted to the pod. Each item in the list contains:
  - **`filePath`**: The path to the original file
  - **`fileKey`**: The key for the secret value in `hub/secret.yaml` 

The deployment requires three sets of volume mounts, each serving a specific purpose:  

- **`ballerina-websubhub-ssl`**: Enables HTTPS for the WebSubHub HTTP endpoint  
- **`ballerina-websubhub-idp`**: Supports secure HTTPS communication between WebSubHub and the IdP JWKS endpoint  
- **`ballerina-websubhub-broker`**: Establishes an mTLS connection between WebSubHub and the Kafka broker

### 2. Deploying the `consolidator`

Helm charts related to the `consolidator` component can be found in the `consolidator` directory. 

To install the charts with the release name `ballerina-consolidator`, go into the `consolidator` directory and run the following command:

```sh
    $ cd consolidator
    $ helm install ballerina-consolidator .
```

To uninstall/delete the `ballerina-consolidator` deployment, run the following command:

```sh
    $ helm delete ballerina-consolidator
```

#### Configurations

The consolidator container image related configurations can be found under `deployment.image` in the `consolidator/values.yaml`.

| Configuration  | Description                        |
|-------------- |-------------------------------------|
| `repository`  | Image repository.                   |
| `pullPolicy`  | Image pull policy for the deployment|
| `tag`         | Image tag                           |

All the package related configurations can be found under `deployment.config` in the `consolidator/values.yaml`. 

Following are a list of configurations and their usage.

| Configuration               | Description                                                                             |
|-----------------------------|-----------------------------------------------------------------------------------------|
| `port`                      | The port that is used to start the consolidator state snapshot endpoint                 |
| `kafka.bootstrap_node`      | IP and port of the Kafka bootstrap node                                                 |
| `kafka.max_poll_records`    | Maximum number of records returned in a single call to consumer-poll                    |
| `kafka.truststore_name`     | The client truststore file name used for mTLS connection from `consolidator` to `broker`|
| `kafka.truststore_password` | The client truststore password                                                          |
| `kafka.keystore_name`       | The client keystore file name used for mTLS connection from `consolidator` to `broker`  |
| `kafka.keystore_password`   | The client keystore password                                                            |


#### Volume mounts

Apart from the above configurations, several volume mounts are required for the deployment. All volume mounts are Kubernetes secrets, and they are listed under `deployment.secrets` in `consolidator/values.yaml`.  

Each secret follows the structure below:  

- **`name`**: Name of the secret
- **`mountPath`**: The path on the pod where the secrets should be mounted  
- **`content`**: A list of secrets to be mounted to the pod. Each item in the list contains:
  - **`filePath`**: The path to the original file
  - **`fileKey`**: The key for the secret value in `hub/secret.yaml` 

The deployment requires three sets of volume mounts, each serving a specific purpose:  

- **`ballerina-consolidator-broker`**: Establishes an mTLS connection between consolidator and the Kafka broker
