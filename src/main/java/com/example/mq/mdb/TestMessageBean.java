package com.example.mq.mdb;

import jakarta.ejb.ActivationConfigProperty;
import jakarta.ejb.MessageDriven;
import jakarta.jms.Message;
import jakarta.jms.MessageListener;
import jakarta.jms.TextMessage;

/**
 * Minimal MDB for SSCCE reproduction.
 *
 * Fixed: Added connectionFactoryLookup to use configured ConnectionFactory.
 */
@MessageDriven(
    name = "TestMessageBean",
    activationConfig = {
        @ActivationConfigProperty(
            propertyName = "destinationType",
            propertyValue = "jakarta.jms.Queue"
        ),
        @ActivationConfigProperty(
            propertyName = "destination",
            propertyValue = "DEV.QUEUE.1"
        ),
        @ActivationConfigProperty(
            propertyName = "connectionFactoryLookup",
            propertyValue = "jms/MQConnectionFactory"
        )
    }
)
public class TestMessageBean implements MessageListener {

    @Override
    public void onMessage(Message message) {
        try {
            if (message instanceof TextMessage) {
                TextMessage textMessage = (TextMessage) message;
                String text = textMessage.getText();
                System.out.println("MDB RECEIVED MESSAGE: " + text);
            } else {
                System.out.println("MDB RECEIVED NON-TEXT MESSAGE: " + message.getClass().getName());
            }
        } catch (Exception e) {
            System.err.println("MDB ERROR: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
