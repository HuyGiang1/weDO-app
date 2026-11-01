import java.net.HttpURLConnection;
import java.net.URI;

/** Small JRE-only probe; no curl, credentials, response bodies or external hosts. */
public final class Healthcheck {
    public static void main(String[] args) {
        HttpURLConnection connection = null;
        int result = 1;
        try {
            int port = args.length == 0 ? 8080 : Integer.parseInt(args[0]);
            if (port < 1 || port > 65535) throw new IllegalArgumentException();
            connection = (HttpURLConnection) URI.create(
                    "http://127.0.0.1:" + port + "/actuator/health").toURL().openConnection();
            connection.setConnectTimeout(2000);
            connection.setReadTimeout(2000);
            connection.setInstanceFollowRedirects(false);
            result = connection.getResponseCode() == 200 ? 0 : 1;
        } catch (Exception unavailable) {
            // Never log response content, credentials or environment variables.
        } finally {
            if (connection != null) connection.disconnect();
        }
        System.exit(result);
    }
}
