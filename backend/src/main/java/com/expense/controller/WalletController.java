package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.wallet.WalletDto;
import com.expense.dto.wallet.WalletRequest;
import com.expense.service.WalletService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/wallets")
@RequiredArgsConstructor
public class WalletController {

    private final WalletService walletService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<WalletDto>>> getAll() {
        List<WalletDto> wallets = walletService.getAll();
        return ResponseEntity.ok(ApiResponse.success(wallets));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<WalletDto>> getById(@PathVariable Long id) {
        WalletDto wallet = walletService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(wallet));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<WalletDto>> create(@Valid @RequestBody WalletRequest request) {
        WalletDto wallet = walletService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Wallet created", wallet));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<WalletDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody WalletRequest request) {
        WalletDto wallet = walletService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Wallet updated", wallet));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        walletService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Wallet deleted", null));
    }
}
