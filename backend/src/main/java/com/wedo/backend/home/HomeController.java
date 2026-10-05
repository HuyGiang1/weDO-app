package com.wedo.backend.home;

import com.wedo.backend.security.AuthenticatedUserPrincipal;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {
    private final HomeService home;

    public HomeController(HomeService home) { this.home = home; }

    @GetMapping("/api/v1/home")
    public HomeDtos.Response get(@AuthenticationPrincipal AuthenticatedUserPrincipal principal) {
        return home.get(principal.userId());
    }

    @GetMapping("/api/v1/me/actions-required")
    public List<HomeDtos.RequiredAction> actionsRequired(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal) {
        return home.actionsRequired(principal.userId());
    }
}
