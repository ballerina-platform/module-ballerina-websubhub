# ------------------------------------------------------------------------
#
# Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
#
# This software is the property of WSO2 LLC. and its suppliers, if any.
# Dissemination of any information or reproduction of any material contained
# herein in any form is strictly forbidden, unless permitted by WSO2
# expressly. You may not alter or remove any copyright or other notice from
# copies of this content.
#
# ------------------------------------------------------------------------

FROM confluentinc/cp-server@sha256:b0a2e53d9702dcef964dab5d510938811b782dfaacdf82371608e602c38e3072
LABEL maintainer="WSO2"

COPY ../_resources/trustoresandkeystores/broker_keystore_creds /etc/kafka/secrets/broker_keystore_creds
COPY ../_resources/trustoresandkeystores/broker_sslkey_creds /etc/kafka/secrets/broker_sslkey_creds
COPY ../_resources/trustoresandkeystores/broker_truststore_creds /etc/kafka/secrets/broker_truststore_creds
COPY ../_resources/trustoresandkeystores/kafka.broker.keystore.jks /etc/kafka/secrets/kafka.broker.keystore.jks
COPY ../_resources/trustoresandkeystores/kafka.broker.truststore.jks /etc/kafka/secrets/kafka.broker.truststore.jks

USER appuser
CMD ["/etc/confluent/docker/run"]
