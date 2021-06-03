# Kafka Startup Guide #

* Download **Apache Kafka** from [here](https://kafka.apache.org/downloads).

* Extract the `zip` file and go into `kafka_2.13-2.7.X` directory.

* Run following command to start the `kafka zookeeper`.

```sh
    ./bin/zookeeper-server-start.sh config/zookeeper.properties
```

* Run following command to start the `kafka broker`.

```sh
    ./bin/kafka-server-start.sh config/server.properties
```

* For more information on **Apache Kafka** go through [following guides](https://kafka.apache.org/quickstart).
