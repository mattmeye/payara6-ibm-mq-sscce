package com.example.mq.ssl;

import javax.net.ssl.*;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.security.KeyStore;
import java.security.SecureRandom;

/**
 * Custom SSLSocketFactory for IBM MQ connections that uses a specific truststore.
 * This allows IBM MQ client to validate server certificates without interfering
 * with Payara's internal SSL configuration.
 *
 * Configuration via IBM MQ connection factory properties:
 * - Set this class as the SSLSocketFactory implementation
 * - Truststore path and password configured via system properties or constructor
 */
public class MQTruststoreSSLSocketFactory extends SSLSocketFactory {

    private final SSLSocketFactory delegate;

    /**
     * Default constructor required by IBM MQ.
     * Reads configuration from system properties:
     * - mq.ssl.trustStore: Path to truststore file
     * - mq.ssl.trustStorePassword: Truststore password
     * - mq.ssl.trustStoreType: Truststore type (default: PKCS12)
     */
    public MQTruststoreSSLSocketFactory() throws Exception {
        String trustStorePath = System.getProperty("mq.ssl.trustStore",
                "/opt/payara/certs/payara/payara-truststore.p12");
        String trustStorePassword = System.getProperty("mq.ssl.trustStorePassword", "payara");
        String trustStoreType = System.getProperty("mq.ssl.trustStoreType", "PKCS12");

        System.out.println("[MQTruststoreSSLSocketFactory] Initializing with:");
        System.out.println("  TrustStore: " + trustStorePath);
        System.out.println("  Type: " + trustStoreType);

        // Load truststore
        KeyStore trustStore = KeyStore.getInstance(trustStoreType);
        try (FileInputStream fis = new FileInputStream(trustStorePath)) {
            trustStore.load(fis, trustStorePassword.toCharArray());
        }

        // Initialize TrustManagerFactory
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(
                TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(trustStore);

        // Initialize SSLContext with the TrustManagers
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, tmf.getTrustManagers(), new SecureRandom());

        // Get the delegate factory from the initialized context
        this.delegate = sslContext.getSocketFactory();

        System.out.println("[MQTruststoreSSLSocketFactory] Successfully initialized");
    }

    // Delegate all SSLSocketFactory methods to the configured factory

    @Override
    public String[] getDefaultCipherSuites() {
        return delegate.getDefaultCipherSuites();
    }

    @Override
    public String[] getSupportedCipherSuites() {
        return delegate.getSupportedCipherSuites();
    }

    @Override
    public Socket createSocket(Socket socket, String host, int port, boolean autoClose)
            throws IOException {
        return delegate.createSocket(socket, host, port, autoClose);
    }

    @Override
    public Socket createSocket(String host, int port) throws IOException {
        return delegate.createSocket(host, port);
    }

    @Override
    public Socket createSocket(String host, int port, InetAddress localHost, int localPort)
            throws IOException {
        return delegate.createSocket(host, port, localHost, localPort);
    }

    @Override
    public Socket createSocket(InetAddress host, int port) throws IOException {
        return delegate.createSocket(host, port);
    }

    @Override
    public Socket createSocket(InetAddress address, int port, InetAddress localAddress,
                               int localPort) throws IOException {
        return delegate.createSocket(address, port, localAddress, localPort);
    }
}
