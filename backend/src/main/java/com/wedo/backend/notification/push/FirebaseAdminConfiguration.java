package com.wedo.backend.notification.push;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class FirebaseAdminConfiguration {

    @Bean(destroyMethod = "")
    FirebaseApp firebaseAdminApp() throws IOException {
        List<FirebaseApp> apps = FirebaseApp.getApps();
        for (FirebaseApp app : apps) {
            if (FirebaseApp.DEFAULT_APP_NAME.equals(app.getName())) {
                return app;
            }
        }
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.getApplicationDefault())
                .build();
        return FirebaseApp.initializeApp(options);
    }

    @Bean
    FirebaseMessaging firebaseMessaging(FirebaseApp firebaseAdminApp) {
        return FirebaseMessaging.getInstance(firebaseAdminApp);
    }
}
