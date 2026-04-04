package com.elastic.workshop.controller;

import com.elastic.workshop.model.User;
import com.elastic.workshop.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
public class UserController {

    @Autowired
    private UserService userService;

    @GetMapping("/")
    public String index(Model model) {
        List<User> users = userService.getAllUsers();
        model.addAttribute("users", users);
        model.addAttribute("userCount", users.size());
        return "index";
    }

    @PostMapping("/users")
    public String createUser(
            @RequestParam String name,
            @RequestParam String email,
            Model model) {
        userService.createUser(name, email);
        return "redirect:/";
    }

    @PostMapping("/users/{id}/delete")
    public String deleteUser(@PathVariable Long id) {
        userService.deleteUser(id);
        return "redirect:/";
    }

    @GetMapping("/health")
    @ResponseBody
    public String health() {
        return "{\"status\":\"UP\",\"service\":\"java-frontend\"}";
    }
}
