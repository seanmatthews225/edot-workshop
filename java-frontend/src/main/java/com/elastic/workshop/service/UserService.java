package com.elastic.workshop.service;

import com.elastic.workshop.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    @Value("${python.backend.url:http://localhost:8000}")
    private String pythonBackendUrl;

    @Autowired
    private RestTemplate restTemplate;

    public List<User> getAllUsers() {
        try {
            ResponseEntity<List<User>> response = restTemplate.exchange(
                pythonBackendUrl + "/api/users",
                HttpMethod.GET,
                null,
                new ParameterizedTypeReference<List<User>>() {}
            );
            return response.getBody() != null ? response.getBody() : Collections.emptyList();
        } catch (RestClientException e) {
            logger.error("Failed to fetch users from Python backend: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    public void createUser(String name, String email) {
        try {
            Map<String, String> body = new HashMap<>();
            body.put("name", name);
            body.put("email", email);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, String>> request = new HttpEntity<>(body, headers);

            restTemplate.postForEntity(pythonBackendUrl + "/api/users", request, Object.class);
        } catch (RestClientException e) {
            logger.error("Failed to create user: {}", e.getMessage());
        }
    }

    public void deleteUser(Long id) {
        try {
            restTemplate.delete(pythonBackendUrl + "/api/users/" + id);
        } catch (RestClientException e) {
            logger.error("Failed to delete user {}: {}", id, e.getMessage());
        }
    }
}
