package com.expense.controller;

import com.expense.service.ExportService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@RestController
@RequestMapping("/export")
@RequiredArgsConstructor
public class ExportController {

    private final ExportService exportService;

    @GetMapping("/transactions")
    public ResponseEntity<byte[]> exportTransactions(
            @RequestParam(defaultValue = "pdf") String format,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) throws Exception {

        LocalDate start = startDate != null ? startDate : LocalDate.now().withDayOfMonth(1);
        LocalDate end = endDate != null ? endDate : LocalDate.now();

        byte[] data;
        String contentType;
        String filename;

        if ("excel".equalsIgnoreCase(format) || "xlsx".equalsIgnoreCase(format)) {
            data = exportService.exportExcel(start, end);
            contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            filename = "bao-cao-giao-dich-" + start.format(DateTimeFormatter.ofPattern("yyyyMM")) + ".xlsx";
        } else {
            data = exportService.exportPdf(start, end);
            contentType = "application/pdf";
            filename = "bao-cao-giao-dich-" + start.format(DateTimeFormatter.ofPattern("yyyyMM")) + ".pdf";
        }

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .body(data);
    }
}
