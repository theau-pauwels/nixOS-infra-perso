// JOAL patch: permit STOMP WebSocket endpoint in Spring Security.
//
// JOAL's WebSecurityConfig uses .anyRequest().denyAll(), which blocks
// the STOMP handshake endpoint (/joal-vps). This class adds a
// higher-priority SecurityFilterChain that permits all requests to
// the STOMP path, allowing WebSocket connections to pass through
// before JOAL's denyAll() filter runs.
//
// Compile with:
//   javac -source 11 -target 11 -cp joal.jar -d . StompPermitConfig.java
//   jar cf stomp-patch.jar org/
//
// Then inject into the JOAL fat JAR:
//   zip -q joal.jar BOOT-INF/classes/org/araymond/joal/web/config/security/StompPermitConfig.class

package org.araymond.joal.web.config.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class StompPermitConfig {
    @Bean
    @Order(Ordered.HIGHEST_PRECEDENCE)
    SecurityFilterChain stompFilterChain(HttpSecurity http) throws Exception {
        return http.antMatcher("/joal-vps/**")
            .authorizeRequests(a -> a.anyRequest().permitAll())
            .csrf(c -> c.disable()).build();
    }
}
