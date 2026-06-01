package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.user.ChangePasswordRequest;
import com.expense.dto.user.UserDto;
import com.expense.dto.user.UserProfileRequest;
import com.expense.dto.user.UserUpdateRequest;
import com.expense.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> getCurrentUser() {
        UserDto user = userService.getCurrentUser();
        return ResponseEntity.ok(ApiResponse.success(user));
    }

    @PutMapping("/me")
    public ResponseEntity<ApiResponse<UserDto>> updateUser(@Valid @RequestBody UserUpdateRequest request) {
        UserDto user = userService.updateUser(request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated", user));
    }

    @PatchMapping("/me/profile")
    public ResponseEntity<ApiResponse<UserDto>> updateProfile(@Valid @RequestBody UserProfileRequest request) {
        UserDto user = userService.updateProfile(request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated", user));
    }

    @PatchMapping("/me/password")
    public ResponseEntity<ApiResponse<Void>> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(request);
        return ResponseEntity.ok(ApiResponse.success("Mật khẩu đã được thay đổi", null));
    }
}
