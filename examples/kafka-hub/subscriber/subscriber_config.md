## WebSub Subscriber configurations

Following configurations are available as environment variables for the sample WebSub subscriber.

| Environment Variable Name | Description                                                                | Usage Example                                     |
|---------------------------|----------------------------------------------------------------------------|---------------------------------------------------|
| `HUB_URL`                 | The URL of the WebSub Hub to connect with.                                 | `-e HUB_URL="https://hub1:9000/hub"`              |
| `TOPIC_NAME`              | The Kafka topic name to which the subscriber should subscribe.             | `-e TOPIC_NAME="topic-1"`                         |
| `CONSUMER_GROUP`          | The name of the Kafka consumer group that the subscriber belongs to.       | `-e CONSUMER_GROUP="group-1"`                     |
| `TOPIC_PARTITIONS`        | A comma-separated list of Kafka topic partitions to subscribe to.          | `-e TOPIC_PARTITIONS="0,1,2"`                     |
| `UNSUB_ON_SHUTDOWN`       | Enables or disables unsubscription when the subscriber shuts down.         | `-e UNSUB_ON_SHUTDOWN="true"`                     |
