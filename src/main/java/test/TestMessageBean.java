package test;

import jakarta.ejb.ActivationConfigProperty;
import jakarta.ejb.MessageDriven;
import jakarta.jms.Message;
import jakarta.jms.MessageListener;
import jakarta.jms.TextMessage;

/**
 * Minimal MDB for SSCCE reproduction.
 *
 * Expected: Should be activated and registered during deployment.
 * Actual: Completely ignored (silent failure).
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
