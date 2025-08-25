## WebSub Subscriber configurations

Following configurations are available as environment variables for the sample WebSub subscriber.

| Environment Variable Name | Description                                                                | Usage Example                                     |
|---------------------------|----------------------------------------------------------------------------|---------------------------------------------------|
| `HUB_URL`                 | The URL of the WebSub Hub to connect with.                                 | `-e HUB_URL="https://hub1:9000/hub"`              |
| `TOPIC_NAME`              | The Kafka topic name to which the subscriber should subscribe.             | `-e TOPIC_NAME="topic-1"`                         |
| `CONSUMER_GROUP`          | The name of the Kafka consumer group that the subscriber belongs to.       | `-e CONSUMER_GROUP="group-1"`                     |
| `TOPIC_PARTITIONS`        | A comma-separated list of Kafka topic partitions to subscribe to.          | `-e TOPIC_PARTITIONS="0,1,2"`                     |
| `NUMBER_OF_REQUESTS`        | Number of messages which should be published.          | `-e NUMBER_OF_REQUESTS=1000`                     |
| `PAYLOAD_SIZE`        | The size of the payload to be used.          | `-e PAYLOAD_SIZE="100B"`                     |
| `NUMBER_OF_SUBSCRIBERS`        | A number of subscribers.          | `-e NUMBER_OF_SUBSCRIBERS=1`                     |
| `KAFKA_URL`        | The broker URL.          | `-e KAFKA_URL="broker:9094"`                     |
